package MR::Rest::Response::Stream;

use Mouse;

extends 'MR::Rest::Response';

override render => sub {
    my ($self) = @_;
    return [ $self->status, $self->_plain_headers ];
};

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
