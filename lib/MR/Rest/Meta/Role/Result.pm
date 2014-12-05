package MR::Rest::Meta::Role::Result;

use Mouse;

extends 'Mouse::Meta::Role';
with 'MR::Rest::Meta::Role::Trait::Result';

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
