package MR::Rest::Response::Root;

use Mouse;

with 'MR::Rest::Role::Response';
with 'MR::Rest::Role::Response::JSON';

has data => (
    is  => 'ro',
    isa => 'HashRef | Object',
    required => 1,
);

sub root { shift->data }

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
