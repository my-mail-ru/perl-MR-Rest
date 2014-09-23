package MR::Rest::Meta::Role::Trait::Parameters;

use Mouse::Role;

sub add_parameter {
    my $self = shift;
    my $name = shift;
    my %args = @_ == 1 ? ref $_[0] ? %{$_[0]} : (isa => $_[0]) : @_;
    return $self->add_attribute(
        $name  => %args,
        traits => ['MR::Rest::Meta::Attribute::Trait::Parameter'],
    );
}

sub get_all_parameters {
    my ($self) = @_;
    return grep $_->does('MR::Rest::Meta::Attribute::Trait::Parameter'), $self->get_all_attributes();
}

no Mouse::Role;

1;
