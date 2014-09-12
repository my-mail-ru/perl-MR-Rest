package MR::Rest::Context;

use Mouse;

use Encode;
use URI::Escape::XS;

use MR::Rest::Type;

with 'MR::Rest::Role::Response';

has env => (
    is  => 'ro',
    isa => 'HashRef',
    required => 1,
);

has params => (
    is  => 'ro',
    isa => 'MR::Rest::Parameters',
    required => 1,
);

sub validate_input {
    my ($self) = @_;
    $self->params->validate();
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
