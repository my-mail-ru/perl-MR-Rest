package MR::Rest::Meta::Role::Parameters;

use Mouse;

extends 'Mouse::Meta::Role';
with 'MR::Rest::Meta::Role::Trait::Parameters';

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
