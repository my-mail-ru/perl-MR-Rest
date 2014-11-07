package MR::Rest::Response::List;

use Mouse;

extends 'MR::Rest::Response';
with 'MR::Rest::Role::Response::JSON';

has data => (
    is  => 'rw',
    isa => 'ArrayRef',
    required => 1,
);

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
