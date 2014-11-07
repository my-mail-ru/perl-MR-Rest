package MR::Rest::Swagger;

use MR::Rest;

use MR::Rest::Type;
use MR::Rest::Response::Root;

doc 'Swagger specifications';

result 'MR::Rest::Swagger::Info' => {
    title             => 'Str',
    description       => 'Str',
    termsOfServiceUrl => { isa => 'Str', required => 0 },
    contact           => { isa => 'Str', required => 0 },
    license           => { isa => 'Str', required => 0 },
    licenseUrl        => { isa => 'Str', required => 0 },
};

result 'MR::Rest::Swagger::Resource' => {
    path        => 'Str',
    description => { isa => 'Str', required => 0 },
};

controller 'GET /devel/doc/' => (
    doc      => q/The Resource Listing serves as the root document for the API description. It contains general information about the API and an inventory of the available resources./,
    response => {
        isa    => 'MR::Rest::Response::Root',
        schema => {
            swaggerVersion => 'Str',
            apis           => 'ArrayRef[MR::Rest::Swagger::Resource]',
            apiVersion     => { isa => 'Str', required => 0 },
            info           => { isa => 'MR::Rest::Swagger::Info', required => 0 },
#           authorizations => { isa => '', required => 0 },
        },
    },
    handler  => sub {
        my ($c) = @_;
        return {
            swaggerVersion => '1.2',
            apis => [ map +{ path => $_->name, $_->doc ? (description => $_->doc) : () },  MR::Rest::Meta::Class::Trait::Controllers->controllers_metas() ],
        };
    },
);

result 'MR::Rest::Swagger::DataType' => {
    type         => 'Str',
#   '$ref'       => 'Str',
    format       => { isa => 'Str', required => 0 },
    defaultValue => { isa => 'Maybe[Str]', required => 0 },
    enum         => { isa => 'ArrayRef[Str]', required => 0 },
    minimum      => { isa => 'Str', required => 0 },
    maximum      => { isa => 'Str', required => 0 },
    items        => { isa => 'MR::Rest::Swagger::DataType', required => 0 },
    uniqueItems  => { isa => 'Bool', required => 0 },
};

result 'MR::Rest::Swagger::Parameter' => (
    also   => 'MR::Rest::Swagger::DataType',
    fields => {
        paramType     => 'Str',
        name          => 'Str',
        description   => { isa => 'Str', required => 0 },
        required      => { isa => 'Bool', required => 0 },
        allowMultiple => { isa => 'Bool', required => 0 },
    }
);

result 'MR::Rest::Swagger::ResponseMessage' => {
    code          => 'Int',
    message       => 'Str',
    responseModel => { isa => 'Str', required => 0 },
};

result 'MR::Rest::Swagger::Operation' => (
    also => 'MR::Rest::Swagger::DataType',
    fields => {
        method           => 'Str',
        summary          => { isa => 'Str', required => 0 },
        notes            => { isa => 'Str', required => 0 },
        nickname         => 'Str',
#       authorizations   => { isa => '', required => 0 },
        parameters       => 'ArrayRef[MR::Rest::Swagger::Parameter]',
        responseMessages => { isa => 'ArrayRef[MR::Rest::Swagger::ResponseMessage]', required => 0 },
        produces         => { isa => 'ArrayRef[Str]', required => 0 },
        consumes         => { isa => 'ArrayRef[Str]', required => 0 },
        depricated       => { isa => 'Str', required => 0 },
    }
);

result 'MR::Rest::Swagger::API' => {
    path        => 'Str',
    description => { isa => 'Str', required => 0 },
    operations  => 'ArrayRef[MR::Rest::Swagger::Operation]',
};

result 'MR::Rest::Swagger::Property' => (
    also => 'MR::Rest::Swagger::DataType',
    fields => {
        name        => 'Str',
        description => { isa => 'Str', required => 0 },
    }
);

result 'MR::Rest::Swagger::Model' => {
    id            => 'Str',
    description   => { isa => 'Str', required => 0 },
    required      => { isa => 'ArrayRef[Str]', required => 0 },
    properties    => { 'name:' => 'MR::Rest::Swagger::Property' },
    subTypes      => { isa => 'ArrayRef[Str]', required => 0 },
    discriminator => { isa => 'Str', required => 0 },
};

controller 'GET /devel/doc/{name}' => (
    doc => q/The API Declaration provides information about an API exposed on a resource./,
    params   => {
        name => 'MR::Rest::Type::ControllersName',
    },
    response => {
        isa    => 'MR::Rest::Response::Root',
        schema => {
            swaggerVersion => 'Str',
            apiVersion     => { isa => 'Str', required => 0 },
            basePath       => 'Str',
            resourcePath   => { isa => 'Str', required => 0 },
            apis           => 'ArrayRef[MR::Rest::Swagger::API]',
            models         => { isa => 'HashRef[MR::Rest::Swagger::Model]', hashby => 'id', required => 0 },
            produces       => { isa => 'ArrayRef[Str]', required => 0 },
            consumes       => { isa => 'ArrayRef[Str]', required => 0 },
#           authorizations => { isa => '', required => 0 },
        },
    },
    handler  => sub {
        my ($c) = @_;
        my (@uri, %apis, @results, @models, %models);
        foreach my $controller (@{$c->params->name->meta->controllers}) {
            push @uri, $controller->uri;
            my $ok = $controller->responses->meta->responses->{ok};
            my $type = $ok->schema ? $ok->name : undef;
            push @results, $type if $type;
            my @responses;
            foreach my $response (values %{$controller->responses->meta->responses}) {
                my $type = $response->schema ? $response->name : undef;
                push @results, $type if $type;
                push @responses, {
                    code          => $response->status,
                    responseModel => $type || 'void',
                    message       => defined $response->doc ? $response->doc : "",
                };
            }
            push @{$apis{$controller->uri}}, {
                method     => $controller->method,
                $controller->doc ? (
                    summary => do { my $d = $controller->doc; $d =~ s/\.(?:\s.*)$//s; $d },
                    notes   => $controller->doc,
                ) : (),
                nickname   => $controller->alias,
                parameters => [
                    map +{
                        paramType => $_->in,
                        name      => $_->name,
                        required  => $_->is_required,
                        $_->doc ? (description => $_->doc) : (),
                        data_type($_->type_constraint, []),
                    }, $controller->params_meta->get_all_parameters()
                ],
                type             => $type || 'void',
                responseMessages => [ sort { $a->{code} <=> $b->{code} } @responses ],
            };
        }
        my @apis = map {
            my $o = delete $apis{$_};
            $o ? { path => $_, operations => $o } : ();
        } @uri;
        while (my $name = shift @results) {
            next if $models{$name};
            $models{$name} = 1;
            my $response = MR::Rest::Meta::Response->response($name);
            my $result = $response && $response->class eq 'MR::Rest::Response::Error' ? "MR::Rest::Response::Error::Result"->meta : $name->meta;
            my @properties = map +{
                name => $_->name,
                $_->doc ? (description => $_->doc) : (),
                data_type($_->type_constraint, \@results),
                $response && exists $response->args->{$_->name} ? (defaultValue => $response->args->{$_->name}) : (),
            }, $result->get_all_fields();
            push @models, {
                id          => $name,
                properties  => \@properties,
                required    => [ map { $_->is_required ? $_->name : () } $result->get_all_fields() ],
                $result->doc ? (description => $result->doc) : (),
            };
        }
        return {
            swaggerVersion => '1.2',
            basePath       => sprintf("%s://%s", $c->env->{'psgi.url_scheme'}, $c->env->{HTTP_HOST}),
            produces       => [ 'application/json' ],
            consumes       => [ 'application/x-www-form-urlencoded' ],
            apis           => \@apis,
            models         => \@models,
        };
    },
);

sub data_type {
    my ($type, $results) = @_;
    return $type->is_a_type_of('Int') ? (type => 'integer', $type->name eq 'Int' ? () : (format => $type->name))
        : $type->is_a_type_of('Num') ? (type => 'number', $type->name eq 'Num' ? () : (format => $type->name))
        : $type->is_a_type_of('Str') ? (type => 'string', $type->name eq 'Str' ? () : (format => $type->name))
        : $type->is_a_type_of('Bool') ? (type => 'boolean', $type->name eq 'Bool' ? () : (format => $type->name))
        : $type->is_a_type_of('ArrayRef') ? (type => 'array', items => { data_type($type->type_parameter, $results) })
        : $type->is_a_type_of('HashRef') ? (type => 'object', items => { data_type($type->type_parameter, $results) })
        : $type->is_a_type_of('Maybe') ? (data_type($type->type_parameter, $results), items => { type => 'null' })
        : $type->is_a_type_of('Object') ? do { push @$results, $type->name; (type => $type->name) }
        : (type => 'void');
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
