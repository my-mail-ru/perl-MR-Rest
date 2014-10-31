package MR::Rest::AccessRoles;

use Mouse;

has all => (
    is  => 'ro',
    isa => 'Bool',
    default => 1,
);

has authorized => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
