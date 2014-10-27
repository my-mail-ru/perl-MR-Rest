package MR::Rest::Meta::Controller;

use Mouse;

use Encode;
use JSON::XS;
use URI::Escape::XS;

use MR::Rest::Type;
use MR::Rest::Context;
use MR::Rest::Parameters;

with 'MR::Rest::Role::Doc';

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

has data => (
    is  => 'ro',
    isa => 'Bool',
    default => 1,
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
                    $args{in} = 'PATH' if $is_path{$n} && !exists $args{in};
                    $meta->add_parameter($n, \%args);
                }
            } else {
                Mouse::Util::apply_all_roles($name, $p);
            }
        }
        my %pin = map { $_->name => $_->in } $meta->get_all_parameters();
        foreach my $name (@path_params) {
            confess "Duplicate parameter $name" if $pin{$name} && $pin{$name} ne 'PATH';
            $meta->add_parameter($name, in => 'PATH') unless $pin{$name};
        }
        return $meta;
    },
);

has _result => (
    init_arg => 'result',
    is       => 'ro',
    isa      => 'ArrayRef | HashRef | Str',
    default  => sub { {} },
);

has result_meta => (
    init_arg => undef,
    is       => 'ro',
    does     => 'MR::Rest::Meta::Class::Trait::Result',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $result = $self->_result;
        return $result->meta unless ref $result || $result =~ /^(?:Array|Hash)Ref\[.+\]$/;
        my $name = $self->name . '::Result';
        Mouse->init_meta(for_class => $name);
        Mouse::Util::MetaRole::apply_metaroles(
            for => $name,
            class_metaroles => {
                class => ['MR::Rest::Meta::Class::Trait::Result'],
            },
        );
        my $meta = $name->meta;
        if (ref $result eq 'ARRAY' && @$result == 1) {
            $meta->list(1);
            $result = $result->[0];
        } elsif (ref $result eq 'HASH' && keys %$result == 1 && (keys %$result)[0] =~ /^(?:(.+):|\*)$/) {
            $meta->hashby($1);
            $result = (values %$result)[0];
        } elsif ($result =~ /^ArrayRef\[(.+)\]$/) {
            $result = $1;
            $meta->list(1);
        } elsif ($result =~ /^HashRef\[(.+)\]$/) {
            $result = $1;
            $meta->hashby('');
        }
        foreach my $r (ref $result eq 'ARRAY' ? @$result : $result) {
            if (ref $r eq 'HASH') {
                $meta->add_field($_, $r->{$_}) foreach keys %$r;
            } else {
                Mouse::Util::apply_all_roles($name, $r->isa('Mouse::Role') ? $r : $r->role);
            }
        }
        return $meta;
    },
);

my (@controllers, %controllers, %controllers_by_alias);

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
        or return $class->render(405, undef, [ Allow => join ', ', keys %{$current->{$type}} ]);
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
    my $context = $controller->context_class->new(env => $env, params => $params);
    return $controller->process($context);
}

sub process {
    my ($self, $context) = @_;
    my ($status, $body, $headers, $response);
    eval {
        $body = $self->handle($context);
        $body = { data => $body } if $self->data;
        $response = $context;
        1;
    } or do {
        my $e = $@;
        $body = {};
        if (blessed $e && $e->does('MR::Rest::Role::Response')) {
            $response = $e;
        } else {
            $status = 500;
            $body->{exception_message} = $e; # FIXME is_test_server
        }
    };
    if ($response) {
        $status = 0 + $response->status;
        $headers = $response->headers;
        if ($status >= 400 && $status < 500) {
            $body->{error} = $response->error if defined $response->error;
            $body->{error_description} = $response->error_description if defined $response->error_description;
            $body->{error_uri} = $response->error_uri if defined $response->error_uri;
        }
    }
    return $self->render($status, $body, $headers);
}

sub handle {
    my ($self, $context) = @_;
    $context->validate_input();
    die MR::Rest::Error->new(403)
        unless $self->authorizator->($context->access_roles);
    my $data = $self->handler->($context);
    my $result_meta = $self->result_meta;
    return $result_meta->transformer->($data, $context->access_roles);
}

sub render {
    my ($self, $status, $data, $headers) = @_;
    $data = {} unless ref $data eq 'HASH';
    my $body = eval {
        encode_json($data);
    } || do {
        $data = {};
        $data->{exception_message} = $@; # FIXME is_test_server
        eval { encode_json($data) } || '{}';
    };
    my @headers = $headers ? @$headers : ();
    unless ($status < 200 || $status == 204 || $status == 304) {
        push @headers, 'Content-Type' => 'application/json';
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
    $self->result_meta->make_immutable();
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
