package MR::Rest::Role::Doc;

use Mouse::Role;

has doc => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

no Mouse::Role;

1;
