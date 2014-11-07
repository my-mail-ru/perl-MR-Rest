package MR::Rest::Response::Body;

use Mouse;

use MR::Rest::Type;

extends 'MR::Rest::Response';

has body => (
    is  => 'ro',
    isa => 'ArrayRef[Str] | MR::Rest::Type::BodyHandle',
    required => 1,
);

override _plain_body => sub { $_[0]->body };

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
