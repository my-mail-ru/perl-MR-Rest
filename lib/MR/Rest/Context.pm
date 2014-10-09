package MR::Rest::Context;

use Mouse;

use MR::Rest::AccessRoles;

with 'MR::Rest::Role::Response';

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

has access_roles => (
    is  => 'ro',
    isa => 'MR::Rest::AccessRoles',
    lazy    => 1,
    default => sub { MR::Rest::AccessRoles->new() },
);

sub validate_input {
    my ($self) = @_;
    $self->params->validate();
    return;
}

sub controller {
    MR::Rest::Meta::Controller->controller($_[1]);
}

sub format_uri {
    my ($self, $alias, %params) = @_;
    my $controller = $self->controller($alias)
        or confess "Controller $alias not found";
    return sprintf "%s://%s%s", $self->env->{'psgi.url_scheme'}, $self->env->{HTTP_HOST}, $controller->format_uri(%params);
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
