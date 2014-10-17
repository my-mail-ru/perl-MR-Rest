package MR::Rest::Role::Response;

use Mouse::Role;

has status => (
    is  => 'rw',
    isa => 'MR::Rest::Type::Status',
    lazy    => 1,
    default => 200,
#    trigger => sub { $_[0]->_clear_error() }, FIXME don't trigger on object creation
);

has headers => (
    is  => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

has error => (
    is  => 'rw',
    isa => 'MR::Rest::Type::Error',
    clearer => '_clear_error',
#    trigger => sub { $_[0]->_clear_error_description(); $_[0]->_clear_error_uri() }, FIXME don't trigger on object creation
);

has error_description => (
    is  => 'rw',
    isa => 'Maybe[Str]',
    clearer => '_clear_error_description',
);

has error_uri => (
    is  => 'rw',
    isa => 'Maybe[Str]',
    clearer => '_clear_error_uri',
);

has data => (
    is  => 'rw',
    isa => 'HashRef | ArrayRef',
);

sub add_header {
    my ($self, $name, $value) = @_;
    push @{$self->headers}, $name, $value;
    return;
}

no Mouse::Role;

1;
