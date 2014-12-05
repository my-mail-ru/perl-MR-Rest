package MR::Rest::Context;

use Mouse;

use MR::Rest::AccessRoles;
use MR::Rest::Type;

has env => (
    is  => 'ro',
    isa => 'HashRef',
    required => 1,
);

has params => (
    is  => 'ro',
    isa => 'MR::Rest::Parameters',
    required => 1,
);

has responses => (
    is  => 'ro',
    isa => 'MR::Rest::Type::ResponsesName',
    required => 1,
);

has _operation => (
    init_arg => 'operation',
    is       => 'ro',
    isa      => 'MR::Rest::Operation',
    required => 1,
);

has owner => (
    is  => 'ro',
    isa => 'Maybe[Object]',
    lazy    => 1,
    default => sub { my $cb = $_[0]->_operation->resource->owner; $cb ? do { local $_ = $_[0]->params; $cb->($_[0]) } : undef },
);

has access_roles => (
    is      => 'ro',
    isa     => 'MR::Rest::AccessRoles',
    lazy    => 1,
    default => sub { MR::Rest::AccessRoles->new() },
);

sub validate_input {
    my ($self) = @_;
    $self->params->validate();
    return;
}

sub format_uri {
    my ($self, $alias, %params) = @_;
    my ($method, $res_alias) = split /_/, $alias, 2;
    my $resource = $self->_operation->resource->service->resource($res_alias)
        or confess "Resource $res_alias not found";
    my $op = $resource->operation(uc $method)
        or confess "Operation $alias not found";
    return sprintf "%s://%s%s%s", $self->env->{'psgi.url_scheme'}, $op->resource->service->host, $op->resource->service->base_path, $op->format_uri(%params);
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
