package MR::Rest::Role::Doc;

use Mouse::Role;

has doc => (
    is  => 'ro',
    isa => 'Str',
);

no Mouse::Role;

1;
