package MR::Rest::Meta::Class::Trait::Controllers;

use Mouse::Role;

use MR::Rest::Meta::Controller;

sub add_controller {
    my ($self, $name, %args) = @_;
    my ($method, $uri) = split / /, $name, 2;
    confess "Invalid controller declaration: it should be in form 'METHOD /resource/uri'" unless $uri;
    my $controller = MR::Rest::Meta::Controller->new(
        %args,
        method   => $method,
        uri      => $uri,
        in_class => $self->name,
    );
    return;
}

no Mouse::Role;

1;
