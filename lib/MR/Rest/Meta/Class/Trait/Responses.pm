package MR::Rest::Meta::Class::Trait::Responses;

use Mouse::Role;

has responses => (
    is  => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

sub add_response {
    my ($self, $name, $response) = @_;
    if (!ref $response) {
        $response = MR::Rest::Meta::Response->error_name($name) if $response eq 'error';
        $response = MR::Rest::Meta::Response->response($response);
    } elsif (ref $response eq 'HASH') {
        $response = MR::Rest::Meta::Response->new($response);
    } elsif (ref $response ne 'MR::Rest::Meta::Response') {
        confess "Invalid response: $response";
    }
    return if $self->responses->{$name} && $self->responses->{$name} eq $response;
    confess "Duplicate response: $name" if $self->responses->{$name};
    $self->responses->{$name} = $response;
    $self->add_method($name, $response->response_sub);
    return;
}

no Mouse::Role;

1;
