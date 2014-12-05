package MR::Rest::Meta::Class::Result;

use Mouse;

extends 'Mouse::Meta::Class';
with 'MR::Rest::Meta::Class::Trait::Result';

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
