package MR::Rest::Meta::Role::Trait::CanThrowResponse;

use Mouse::Role;

use MR::Rest::Meta::Response;

has _responses => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'HashRef',
    default  => sub { {} },
);

sub add_response {
    my ($self, $name, $rclass) = @_;
    $rclass = MR::Rest::Meta::Response->error_name($name) if $rclass eq 'error';
    confess "Duplicate response name: $name" if $self->_responses->{$name};
    return $self->_responses->{$name} = MR::Rest::Meta::Response->response($rclass);
}

sub add_error {
    my ($self, $name) = @_;
    return $self->add_response($name, MR::Rest::Meta::Response->error_name($name));
}

no Mouse::Role;

1;
