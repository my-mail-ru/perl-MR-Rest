package MR::Rest::Operation;

use Mouse;

use Encode;
use JSON::XS;
use URI::Escape::XS;

use MR::Metrics;

use MR::Rest::Type;
use MR::Rest::Context;
use MR::Rest::Parameters;
use MR::Rest::Responses;
use MR::Rest::Response::Item;
use MR::Rest::Response::List;

with 'MR::Rest::Role::Doc';

has resource => (
    is  => 'ro',
    isa => 'MR::Rest::Resource',
    required => 1,
    weak_ref => 1,
);

has method => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Method',
    default => 'GET',
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

has name => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $name = $self->alias;
        $name =~ s/(?:^|_)(.)/\u$1/g;
        my $class = sprintf "%s::%s", $_[0]->resource->namespace, $name;
        confess "Class $class already exists" if $class->isa('UNIVERSAL');
        return $class;
    },
);

has alias => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return join '_', lc $self->method, $self->resource->name;
    },
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
        my @allow = grep { $_ ne 'authorized' } @{$self->allow};
        return sub { 1 } if grep { $_ eq 'all' } @allow;
        return sub {
            my ($roles) = @_;
            return 0 unless $roles->authorized;
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
        my $resource_role = $self->resource->params_role;
        Mouse::Util::apply_all_roles($name, $resource_role) if $resource_role;
        my %pin = map { $_->name => $_->in } $meta->get_all_parameters();
        foreach my $name (@path_params) {
            confess "Duplicate parameter $name" if $pin{$name} && $pin{$name} ne 'path';
            $meta->add_parameter($name, in => 'path') unless $pin{$name};
        }
        $meta->make_immutable();
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
        $self->_apply_parameters_changes($meta);
        return $name;
    },
);

has _uri_formatter => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $params = $self->params_meta;
        my @path = map $_->name, grep { $_->in eq 'path' } $params->get_all_parameters();
        my $path_str = join '|', map "\Q$_\E", @path;
        my $path_re = qr/\{($path_str)\}/;
        my @query = map $_->name, grep { $_->in eq 'query' } $params->get_all_parameters();
        my $resource_path = $self->resource->path;
        return sub {
            my ($params) = @_;
            foreach my $name (@path) {
                confess "Parameter '$name' is required" unless defined $params->{$name};
            }
            my $path = $resource_path;
            $path =~ s/$path_re/encodeURIComponent("$params->{$1}")/ge;
            my @qs;
            foreach my $name (@query) {
                push @qs, join '=', encodeURIComponent("$name"), encodeURIComponent("$params->{$name}") if defined $params->{$name};
            }
            $path .= '?' . join '&', @qs if @qs;
            return $path;
        };
    },
);

has _timing_metric => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'MR::Metrics::Timing',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $service = $self->resource->service;
        return MR::Metrics::Timing->new(
            backend => MR::Rest::Config->find($self->resource->in_package)->metrics_backend,
            path    => '{host}.{path}.{method}.{status}.time',
            args    => {
                host   => $service->host,
                path   => $service->base_path . $self->resource->path,
                method => $self->method,
            },
        );
    },
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    if ($args{result}) {
        $args{response} = {
            isa    => $args{method} eq 'GET' && $args{resource}->path =~ /\/$/ ? 'MR::Rest::Response::List' : 'MR::Rest::Response::Item',
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
    my $resource = $self->resource;
    $resource->add_operation($self);
    return;
}

sub process {
    my $self = shift;
    my $timing = $self->_timing_metric->start();
    my $result = $self->_process(@_, $timing);
    $timing->finish(status => $result->[0]) unless ref $result eq 'CODE';
    return $result;
}

sub _process {
    my ($self, $env, $path_params, $timing) = @_;
    my $params = $self->params_meta->new_object(env => $env, path_params => $path_params);
    my $context = $self->context_class->new(env => $env, params => $params, responses => $self->responses, operation => $self);
    my $response = eval { $self->handle($context) } || do {
        my $e = $@;
        return _render_500($e) unless blessed $e && $e->does('MR::Rest::Role::Response');
        $e;
    };
    my %render = (access_roles => $context->access_roles);
    if (ref $response eq 'CODE') {
        return sub {
            my ($responder) = @_;
            my $render;
            $response->(sub {
                $render = eval { $_[0]->render(%render) } || _render_500($@);
                $responder->($render);
            });
            $timing->finish(status => $render->[0]);
            return;
        };
    } else {
        return eval { $response->render(%render) } || _render_500($@);
    }
}

sub _render_500 {
    my ($e) = @_;
    $e ||= 'No response';
    warn "[500] $e";
    my $body = 0 ? $e : ''; # FIXME is_test_server
    return [ 500, [ 'Content-Type' => 'text/plain', 'Content-Length' => length $body ], [ $body ] ];
}

sub handle {
    my ($self, $context) = @_;
    $context->validate_input();
    unless ($self->authorizator->($context->access_roles)) {
        die $context->access_roles->authorized
            ? $context->responses->forbidden
            : $context->responses->unauthorized
    }
    my $response = $self->handler->($context);
    return $response if ref $response eq 'CODE';
    return $response if blessed $response && $response->does('MR::Rest::Role::Response');
    return $self->responses->ok(data => $response);
}

sub format_uri {
    my ($self, %params) = @_;
    return $self->_uri_formatter->(\%params);
}

sub make_immutable {
    my ($self) = @_;
    $self->params_meta->make_immutable();
    $self->responses->meta->make_immutable();
    $self->authorizator;
    return;
}

sub _apply_parameters_changes {
    my ($self, $responses) = @_;
    $responses ||= $self->responses->meta;
    foreach my $param ($self->params_meta->get_all_parameters()) {
        my $type = $param->type_constraint;
        $type = $type->type_parameter if $type->is_a_type_of('Maybe');
        if (my $message = $type->message) {
            my $m = do { local $_ = '%s'; $message->() };
            if (blessed $m && $m->isa('MR::Rest::Response::Error')) {
                $responses->add_response($m->error => 'error');
            }
        }
    }
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
