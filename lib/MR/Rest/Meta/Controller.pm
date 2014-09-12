package MR::Rest::Meta::Controller;

use Mouse;

use Encode;
use JSON::XS;
use URI::Escape::XS;

use MR::Rest::Type;
use MR::Rest::Context;
use MR::Rest::Parameters;

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
);

has handler => (
    is  => 'ro',
    isa => 'CodeRef',
    required => 1,
);

has doc => (
    is  => 'ro',
    isa => 'Str',
);

has in_class => (
    is  => 'ro',
    isa => 'ClassName',
    required => 1,
);

has _params => (
    init_arg => 'params',
    is  => 'ro',
    isa => 'HashRef',
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
    default  => do {
        my %counters;
        sub {
            my ($self) = @_;
            my $pclass = sprintf "%s::Controller%d::Parameters", $self->in_class, ++$counters{$self->in_class};
            Mouse->init_meta(
                for_class  => $pclass,
                base_class => 'MR::Rest::Parameters',
            );
            Mouse::Util::MetaRole::apply_metaroles(
                for => $pclass,
                class_metaroles => {
                    class => ['MR::Rest::Meta::Class::Trait::Parameters'],
                },
            );
            my $pmeta = $pclass->meta;
            my $params = $self->_params;
            foreach my $name (grep $_, @{$self->_path_params}) {
                confess "Duplicate parameter $name" if $params->{$name}->{location} && $params->{$name}->{location} ne 'PATH';
                $params->{$name}->{location} = 'PATH';
            }
            foreach my $name (keys %$params) {
                $pmeta->add_parameter($name, %{$params->{$name}});
            }
            return $pmeta;
        };
    },
);

my (@controllers, %controllers);

sub BUILD {
    my ($self) = @_;
    my $uri = $self->uri;
    my @components = split /\//, $uri;
    confess "Invalid controller declaration: resource uri should start with /" unless shift @components eq '';
    my $params = $self->_path_params;
    my $current = \%controllers;
    foreach my $i (0 .. $#components) {
        if ($components[$i] =~ /^\{(.*)\}$/) {
            $params->[$i] = $1;
        } else {
            $current = $current->{$i}->{$components[$i]} ||= {};
        }
    }
    my $type = $uri =~ /\/$/ ? 'LIST' : $uri =~ /\}$/ ? 'PARAM' : 'EXTRA';
    confess sprintf "Controller for resoure uri %s, method %s is already registered", $uri, $self->method if $current->{$type}->{$self->method};
    $current->{$type}->{$self->method} = $self;
    push @controllers, $self;
    $self->params_meta;
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
    my $type = $uri =~ /\/$/ ? 'LIST' : $params[$#components] ? 'PARAM' : 'EXTRA';
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
    my $context = MR::Rest::Context->new(env => $env, params => $params);
    return $controller->process($context);
}

sub process {
    my ($self, $context) = @_;
    my (%body, $response);
    eval {
        $context->validate_input();
        $body{data} = $self->handler->($context);
        $response = $context;
        1;
    } or do {
        my $e = $@;
        if (blessed $e && $e->does('MR::Rest::Role::Response')) {
            $response = $e;
        } else {
            %body = (status => 500);
            $body{exception_message} = $e; # FIXME is_test_server
        }
    };
    if ($response) {
        $body{status} = $response->status;
        if ($body{status} >= 400 && $body{status} < 500) {
            $body{error} = $response->error if defined $response->error;
            $body{error_description} = $response->error_description if defined $response->error_description;
            $body{error_uri} = $response->error_uri if defined $response->error_uri;
        }
    }
    return $self->render(\%body);
}

sub render {
    my ($class, $data, $headers) = @_;
    $data = { status => $data } unless ref $data;
    my $body = eval {
        encode_json($data);
    } || do {
        $data = { status => 500 };
        $data->{exception_message} = $@; # FIXME is_test_server
        eval { encode_json($data) } || '{ "status": 500 }';
    };
    my $status = $data->{status};
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

sub make_immutable {
    my ($self) = @_;
    $self->params_meta->make_immutable();
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
