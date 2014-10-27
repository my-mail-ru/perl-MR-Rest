package MR::Rest::Swagger;

use MR::Rest;

use MR::Rest::Type;

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
    doc     => q/The Resource Listing serves as the root document for the API description. It contains general information about the API and an inventory of the available resources./,
    data    => 0,
    result  => {
        swaggerVersion => 'Str',
        apis           => 'ArrayRef[MR::Rest::Swagger::Resource]',
        apiVersion     => { isa => 'Str', required => 0 },
        info           => { isa => 'MR::Rest::Swagger::Info', required => 0 },
#        authorizations => { isa => '', required => 0 },
    },
    handler => sub {
        my ($c) = @_;
        return {
            swaggerVersion => '1.2',
            apis => [ map +{ path => $_->name, description => $_->doc },  MR::Rest::Meta::Class::Trait::Controllers->controllers_metas() ],
        };
    },
);

result 'MR::Rest::Swagger::DataType' => {
    type         => 'Str',
#    '$ref'      => 'Str',
    format       => { isa => 'Str', required => 0 },
    defaultValue => { isa => 'Item', required => 0 },
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
        method          => 'Str',
        summary         => { isa => 'Str', required => 0 },
        notes           => { isa => 'Str', required => 0 },
        nickname        => 'Str',
#        authorizations  => { isa => '', required => 0 },
        parameters      => 'ArrayRef[MR::Rest::Swagger::Parameter]',
        responseMessage => { isa => 'ArrayRef[MR::Rest::Swagger::ResponseMessage]', required => 0 },
        produces        => { isa => 'ArrayRef[Str]', required => 0 },
        consumes        => { isa => 'ArrayRef[Str]', required => 0 },
        depricated      => { isa => 'Str', required => 0 },
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
    data    => 0,
    params  => {
        name => 'MR::Rest::Type::ControllersName',
    },
    result  => {
        swaggerVersion => 'Str',
        apiVersion     => { isa => 'Str', required => 0 },
        basePath       => 'Str',
        resourcePath   => { isa => 'Str', required => 0 },
        apis           => 'ArrayRef[MR::Rest::Swagger::API]',
        models         => { isa => 'HashRef[MR::Rest::Swagger::Model]', hashby => 'id', required => 0 },
        produces       => { isa => 'ArrayRef[Str]', required => 0 },
        consumes       => { isa => 'ArrayRef[Str]', required => 0 },
#        authorizations => { isa => '', required => 0 },
    },
    handler => sub {
        my ($c) = @_;
        my (@uri, %apis, @results, @models, %models);
        foreach my $controller (@{$c->params->name->meta->controllers}) {
            push @uri, $controller->uri;
            my $result = $controller->result_meta;
            my $type = $result->name;
            push @results, $type;
            if ($controller->data) {
                $type = "${type}::Root";
                push @models, {
                    id         => $type,
                    properties => [ { name => 'data', $result->list ? (type => 'array', items => { type => $result->name }) : (type => $result->name) } ],
                    required   => [ 'data' ],
                };
            }
            push @{$apis{$controller->uri}}, {
                method     => $controller->method,
                summary    => do { my $d = $controller->doc; $d =~ s/\.(?:\s.*)$//s; $d },
                notes      => $controller->doc,
                nickname   => $controller->alias,
                parameters => [
                    map +{
                        paramType   => $_->in,
                        name        => $_->name,
                        description => $_->doc,
                        required    => $_->is_required,
                        data_type($_->type_constraint, []),
                    }, $controller->params_meta->get_all_parameters()
                ],
                type       => $type,
            };
        }
        my @apis = map {
            my $o = delete $apis{$_};
            $o ? { path => $_, operations => $o } : ();
        } @uri;
        while (my $name = shift @results) {
            next if $models{$name};
            $models{$name} = 1;
            my $result = $name->meta;
            my @properties = map +{
                name        => $_->name,
                description => $_->doc,
                data_type($_->type_constraint, \@results),
            }, $name->meta->get_all_fields();
            push @models, {
                id         => $result->name,
                properties => \@properties,
                required   => [ map { $_->is_required ? $_->name : () } $name->meta->get_all_fields() ],
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
        : $type->is_a_type_of('Object') ? do { push @$results, $type->name; (type => $type->name) }
        : (type => 'void');
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
