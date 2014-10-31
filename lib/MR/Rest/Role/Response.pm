package MR::Rest::Role::Response;

use Mouse::Role;

has status => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Status',
    lazy    => 1,
    default => 200,
);

has headers => (
    is  => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

has body => (
    is  => 'ro',
    isa => 'Str',
    default => '',
);

has access_roles => (
    is  => 'rw',
    isa => 'MR::Rest::AccessRoles',
    lazy    => 1,
    default => sub { confess "access_roles not initialized" },
);

sub add_header {
    my ($self, $name, $value) = @_;
    push @{$self->headers}, $name, $value;
    return;
}

no Mouse::Role;

1;
