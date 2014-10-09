package MR::Rest::AccessRoles;

use Mouse;

has all => (
    is  => 'ro',
    isa => 'Bool',
    default => 1,
);

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
