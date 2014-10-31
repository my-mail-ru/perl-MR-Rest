package MR::Rest::Meta::Controller;

use Mouse;

use Encode;
use JSON::XS;
use URI::Escape::XS;

use MR::Rest::Type;
use MR::Rest::Context;
use MR::Rest::Parameters;
use MR::Rest::Responses;
use MR::Rest::Response::Item;
use MR::Rest::Response::List;

with 'MR::Rest::Meta::Trait::Doc';

has method => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Method',
    default => 'GET',
);

has uri => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has allow => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Allow',
    coerce  => 1,
    default => sub { [ 'all' ] },
);

has handler => (
    is  => 'ro',
    isa => 'CodeRef',
    required => 1,
);

has in_class => (
    is  => 'ro',
    isa => 'ClassName',
    required => 1,
);

has name => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $name = $self->alias;
        $name =~ s/(?:^|_)(.)/\u$1/g;
        my $class = sprintf "%s::%s", $_[0]->in_class, $name;
        confess "Class $class already exists" if $class->isa('UNIVERSAL');
        return $class;
    },
);

has alias => (
    is  => 'rw',
    isa => 'Str',
);

has context_class => (
    is  => 'ro',
    isa => 'ClassName',
    default => 'MR::Rest::Context',
);

has authorizator => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my @allow = @{$self->allow};
        return sub { 1 } if grep { $_ eq 'all' } @allow;
        return sub {
            my ($roles) = @_;
            foreach my $role (@allow) {
                return 1 if $roles->$role;
            }
            return 0;
        };
    },
);

has _params => (
    init_arg => 'params',
    is  => 'ro',
    isa => 'ArrayRef | HashRef | RoleName',
    default => sub { {} },
);

has _path_params => (
    init_arg => undef,
    is  => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

has params_meta => (
    init_arg => undef,
    is       => 'ro',
    does     => 'MR::Rest::Meta::Class::Trait::Parameters',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $name = $self->name . '::Parameters';
        Mouse->init_meta(
            for_class  => $name,
            base_class => 'MR::Rest::Parameters',
        );
        Mouse::Util::MetaRole::apply_metaroles(
            for => $name,
            class_metaroles => {
                class => ['MR::Rest::Meta::Class::Trait::Parameters'],
            },
        );
        my @path_params = grep $_, @{$self->_path_params};
        my %is_path = map { $_ => 1 } @path_params;
        my $meta = $name->meta;
        foreach my $p (ref $self->_params eq 'ARRAY' ? @{$self->_params} : $self->_params) {
            if (ref $p eq 'HASH') {
                foreach my $n (keys %$p) {
                    my %args = ref $p->{$n} ? %{$p->{$n}} : (isa => $p->{$n});
                    $args{in} = 'path' if $is_path{$n} && !exists $args{in};
                    $meta->add_parameter($n, \%args);
                }
            } else {
                Mouse::Util::apply_all_roles($name, $p);
            }
        }
        my %pin = map { $_->name => $_->in } $meta->get_all_parameters();
        foreach my $name (@path_params) {
            confess "Duplicate parameter $name" if $pin{$name} && $pin{$name} ne 'path';
            $meta->add_parameter($name, in => 'path') unless $pin{$name};
        }
        return $meta;
    },
);

has _responses => (
    init_arg => 'responses',
    is       => 'ro',
    isa      => 'HashRef',
    default  => sub { {} },
);

has responses => (
    init_arg => undef,
    is       => 'ro',
    does     => 'MR::Rest::Type::ResponsesName',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $results = $self->_responses;
        my $name = $self->name . '::Responses';
        Mouse->init_meta(for_class => $name);
        Mouse::Util::MetaRole::apply_metaroles(
            for => $name,
            class_metaroles => {
                class => ['MR::Rest::Meta::Class::Trait::Responses'],
            },
        );
        my $meta = $name->meta;
        if (ref $results eq 'HASH') {
            foreach my $name (keys %$results) {
                my $val = $results->{$name};
                if (ref $val eq 'HASH') {
                    my $suffix = $name;
                    $suffix =~ s/(?:^|_)(.)/\u$1/g;
                    $val = { name => $self->name . "::Response::$suffix", %$val };
                }
                $meta->add_response($name, $val);
            }
        } else {
            confess "Invalid results definition";
        }
        my $r = $self->params_meta->responses->meta->responses;
        foreach my $name (keys %$r) {
            $meta->add_response($name, $r->{$name});
        }
        $meta->add_response(forbidden => 'error') unless grep { $_ eq 'all' } @{$self->allow};
        return $name;
    },
);

my (@controllers, %controllers, %controllers_by_alias);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    if ($args{result}) {
        $args{response} = {
            isa    => $args{method} eq 'GET' && $args{uri} =~ /\/$/ ? 'MR::Rest::Response::List' : 'MR::Rest::Response::Item',
            schema => { data => delete $args{result} },
        };
    }
    if ($args{response}) {
        $args{response}{doc} = 'Response successfully processed' if ref $args{response} eq 'HASH' && !defined $args{response}{doc};
        $args{responses}{ok} = delete $args{response};
    }
    return $class->$orig(\%args);
};

sub BUILD {
    my ($self) = @_;
    my $uri = $self->uri;
    my @components = split /\//, $uri;
    confess "Invalid controller declaration: resource uri should start with /" unless shift @components eq '';
    my @alias = (lc $self->method);
    my $params = $self->_path_params;
    my $current = \%controllers;
    foreach my $i (0 .. $#components) {
        if ($components[$i] =~ /^\{(.*)\}$/) {
            $params->[$i] = $1;
        } else {
            $current = $current->{$i}->{$components[$i]} ||= {};
            push @alias, $components[$i];
        }
    }
    my $type = $uri =~ /\/$/ ? 'LIST' : $uri =~ /\}$/ ? 'ITEM' : 'EXTRA';
    push @alias, lc $type unless $type eq 'EXTRA';
    confess sprintf "Controller for resource uri %s, method %s is already registered", $uri, $self->method if $current->{$type}->{$self->method};
    $current->{$type}->{$self->method} = $self;
    unless ($self->alias) {
        my $alias = join '_', @alias;
        $alias =~ s/[^a-z0-9_]/_/g;
        $self->alias($alias);
    }
    confess sprintf "Controller with alias %s is already registered", $self->alias if $controllers_by_alias{$self->alias};
    $controllers_by_alias{$self->alias} = $self;
    push @controllers, $self;
    return;
}

sub dispatch {
    my ($class, $env) = @_;
    my $uri = $env->{REQUEST_URI};
    $uri =~ s/\?.*$//;
    my @components = split /\//, $uri;
    confess "Invalid REQUEST_URI: resource uri should start with /" if @components && shift @components ne '';
    my @params;
    my $current = \%controllers;
    foreach my $i (0 .. $#components) {
        if (my $next = $current->{$i}->{$components[$i]}) {
            $current = $next;
        } else {
            $params[$i] = $components[$i];
        }
    }
    my $type = $uri =~ /\/$/ ? 'LIST' : defined $params[$#components] ? 'ITEM' : 'EXTRA';
    return $class->render(404) unless $current->{$type};
    my $controller = $current->{$type}->{$env->{REQUEST_METHOD}}
        or return $class->render(405, [ Allow => join ', ', keys %{$current->{$type}} ]);
    my $paramnames = $controller->_path_params;
    return $class->render(404) unless @$paramnames == @params;
    my %params;
    foreach my $i (0 .. $#$paramnames) {
        return $class->render(404) if defined $params[$i] xor defined $paramnames->[$i];
        if (defined $paramnames->[$i]) {
            $params{$paramnames->[$i]} = decode('UTF-8', decodeURIComponent($params[$i]));
        }
    }
    my $params = $controller->params_meta->new_object(env => $env, path_params => \%params);
    my $responses = $controller->responses;
    my $context = $controller->context_class->new(env => $env, params => $params, responses => $responses);
    return $controller->process($context);
}

sub process {
    my ($self, $context) = @_;
    my ($status, $body, $headers, $response);
    eval {
        $response = $self->handle($context);
        1;
    } or do {
        my $e = $@;
        if (blessed $e && $e->does('MR::Rest::Role::Response')) {
            $response = $e;
        } else {
            $status = 500;
            $body = $e; # FIXME is_test_server
            warn "[500] $e";
        }
    };
    if ($response) {
        eval {
            $response->access_roles($context->access_roles);
            $status = 0 + $response->status;
            $headers = $response->headers;
            $body = $response->body;
            1;
        } or do {
            $status = 500;
            $headers = undef;
            $body = $@; # FIXME is_test_server
            warn "[500] $@";
        };
    }
    return $self->render($status, $headers, $body);
}

sub handle {
    my ($self, $context) = @_;
    $context->validate_input();
    die $context->responses->forbidden
        unless $self->authorizator->($context->access_roles);
    my $response = $self->handler->($context);
    unless (blessed $response && $response->does('MR::Rest::Role::Response')) {
        $response = $self->responses->ok(data => $response);
    }
    return $response;
}

sub render {
    my ($self, $status, $headers, $body) = @_;
    my @headers = $headers ? @$headers : ();
    unless ($status < 200 || $status == 204 || $status == 304) {
        push @headers, 'Content-Length' => length $body;
    }
    return [ $status, \@headers, [ $body ] ];
}

sub controllers {
    return @controllers;
}

sub controller {
    return $controllers_by_alias{$_[1]};
}

sub format_uri {
    my ($self, %params) = @_;
    return $self->params_meta->uri_formatter->($self->uri, \%params);
}

sub make_immutable {
    my ($self) = @_;
    $self->params_meta->make_immutable();
    $self->responses;
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
