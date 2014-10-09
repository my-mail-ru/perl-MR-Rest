package MR::Rest::Meta::Class::Trait::Controllers;

use Mouse::Role;

use MR::Rest::Meta::Controller;

has field_traits => (
    is  => 'rw',
    isa => 'ArrayRef[RoleName]',
    default => sub { [] },
);

has controller_class => (
    is  => 'rw',
    isa => 'ClassName',
    default => 'MR::Rest::Meta::Controller',
);

has controllers => (
    is  => 'ro',
    isa => 'ArrayRef[MR::Rest::Meta::Controller]',
    default => sub { [] },
);

sub add_parameters {
    my ($self, $name, %args) = @_;
    Mouse::Role->init_meta(for_class => $name);
    Mouse::Util::MetaRole::apply_metaroles(
        for => $name,
        role_metaroles => {
            role => ['MR::Rest::Meta::Role::Trait::Parameters'],
        },
    );
    Mouse::Util::apply_all_roles($name, ref $args{also} eq 'ARRAY' ? @{$args{also}} : ($args{also})) if $args{also};
    my $meta = $name->meta;
    foreach my $name (keys %{$args{params}}) {
        $meta->add_parameter($name, %{$args{params}->{$name}});
    }
    foreach my $name (keys %{$args{objects}}) {
        $meta->add_parameter_object($name, %{$args{objects}->{$name}});
    }
    return $meta;
}

sub add_result {
    my ($self, $name, %args) = @_;
    return MR::Rest::Meta::Class::Trait::Result->init_meta(%args, for_class => $name, field_traits => $self->field_traits);
}

sub add_controller {
    my ($self, $name, %args) = @_;
    my ($method, $uri) = split / /, $name, 2;
    confess "Invalid controller declaration: it should be in form 'METHOD /resource/uri'" unless $uri;
    my $controller = $self->controller_class->new(
        %args,
        method   => $method,
        uri      => $uri,
        in_class => $self->name,
    );
    push @{$self->controllers}, $controller;
    return $controller;
}

before make_immutable => sub {
    my ($self) = @_;
    $_->make_immutable() foreach @{$self->controllers};
    return;
};

no Mouse::Role;

1;
