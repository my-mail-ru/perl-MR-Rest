package MR::Rest::Swagger;

use MR::Rest;

use MR::Rest::Type;
use MR::Rest::Response::Root;

use List::MoreUtils qw/uniq/;

service 'Swagger';

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

result 'MR::Rest::Swagger::LoginEndpoint' => {
    url => 'Str',
};

result 'MR::Rest::Swagger::Grant::Implicit' => {
    loginEndpoint => 'MR::Rest::Swagger::LoginEndpoint',
    tokenName     => 'Str',
};

result 'MR::Rest::Swagger::GrantTypes' => {
    implicit => 'MR::Rest::Swagger::Grant::Implicit',
};

result 'MR::Rest::Swagger::Scope' => {
    scope       => 'Str',
    description => { isa => 'Str', required => 0 },
};

result 'MR::Rest::Swagger::Authorization' => {
    type       => 'Str',
    scopes     => 'ArrayRef[MR::Rest::Swagger::Scope]',
    grantTypes => 'MR::Rest::Swagger::GrantTypes',
};

error_response service_not_found => (
    status => 404,
    desc   => 'Service %s not found',
);

resource '/{service_name}/' => (
    params => {
        params  => { service_name => 'Str' },
        objects => {
            service => {
                param     => 'service_name',
                isa       => 'MR::Rest::Service',
                to_object => sub { MR::Rest::Service->find($_) or die $_[0]->meta->responses->service_not_found(args => [$_]) },
            },
        },
        responses => { service_not_found => 'error' },
    },
);

operation GET => (
    doc      => q/The Resource Listing serves as the root document for the API description. It contains general information about the API and an inventory of the available resources./,
    response => {
        isa    => 'MR::Rest::Response::Root',
        schema => {
            swaggerVersion => 'Str',
            apis           => 'ArrayRef[MR::Rest::Swagger::Resource]',
            apiVersion     => { isa => 'Str', required => 0 },
            info           => { isa => 'MR::Rest::Swagger::Info', required => 0 },
            authorizations => { isa => 'HashRef[MR::Rest::Swagger::Authorization]', required => 0 },
        },
    },
    handler  => sub {
        my ($c) = @_;
        my $service = $c->params->service;
        my @packages = uniq map $_->in_package, $service->resources();
        return {
            swaggerVersion => '1.2',
            apis           => [ map +{ path => $_ }, @packages ],
            info           => {
                title       => $service->name,
                description => $service->doc || '',
            },
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

result 'MR::Rest::Swagger::Authorizations' => {
    oauth2 => 'ArrayRef[MR::Rest::Swagger::Scope]',
};

resource '/{service_name}/{package_name}' => (
    params => {
        also   => 'MR::Rest::Swagger::ItemList::Parameters',
        params => { package_name => 'ClassName' },
    },
);

operation GET => (
    doc => q/The API Declaration provides information about an API exposed on a resource./,
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
            authorizations => { isa => 'MR::Rest::Swagger::Authorizations', required => 0 },
        },
    },
    handler  => sub {
        my ($c) = @_;
        my $package = $c->params->package_name;
        my (@apis, @results, %results_default, @errors, @models, %models);
        foreach my $resource (grep { $_->in_package eq $package } $c->params->service->resources()) {
            my @ops;
            foreach my $controller ($resource->operations()) {
                my $type;
                my @responses;
                my $responses = $controller->responses->meta->responses;
                foreach my $name (keys %$responses) {
                    my $response = $responses->{$name};
                    my $model = $response->class eq 'MR::Rest::Response::Error' ? $response->name : $response->schema;
                    push @results, $model if $model;
                    push @responses, {
                        code          => $response->status,
                        responseModel => $model || 'void',
                        message       => defined $response->doc ? $response->doc : "",
                    };
                    $type = $model if $name eq 'ok';
                }
                push @ops, {
                    method     => $controller->method,
                    $controller->doc ? (
                        summary => do { my $d = $controller->doc; $d =~ s/\.(?:\s.*)$//s; $d },
                        notes   => $controller->doc,
                    ) : (),
                    nickname   => $controller->alias,
                    parameters => [
                        map +{
                            paramType => $_->in,
                            name      => $_->in ne 'header' ? $_->name : do { my $n = $_->name; $n =~ s/^(.)/\u$1/; $n =~ s/_(.)/-\u$1/g; $n },
                            required  => $_->is_required,
                            $_->doc ? (description => $_->doc) : (),
                            data_type($_->type_constraint, []),
                        }, $controller->params_meta->get_all_parameters()
                    ],
                    type             => $type || 'void',
                    responseMessages => [ sort { $a->{code} <=> $b->{code} } @responses ],
                };
            }
            push @apis, {
                path       => $resource->path,
                operations => \@ops,
            };
        }
        while (my $name = shift @results) {
            next if $models{$name};
            $models{$name} = 1;
            my $error = $name =~ /^MR::Rest::Response::Error::/ ? MR::Rest::Meta::Response->response($name) : undef;
            my $result = $error ? $error->schema->meta : $name->meta;
            my @properties = map +{
                name => $_->name,
                $_->doc ? (description => $_->doc) : (),
                data_type($_->type_constraint, \@results),
                $error && exists $error->args->{$_->name} ? (defaultValue => $error->args->{$_->name}) : (),
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
