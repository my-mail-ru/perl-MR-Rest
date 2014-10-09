package MR::Rest::Meta::Role::Trait::Parameters;

use Mouse::Role;

sub add_parameter {
    my $self = shift;
    my $name = shift;
    my %args = @_ == 1 ? ref $_[0] ? %{$_[0]} : (isa => $_[0]) : @_;
    $args{traits} = ['MR::Rest::Meta::Attribute::Trait::Parameter', $args{traits} ? @{$args{traits}} : ()];
    return $self->add_attribute($name => %args);
}

sub get_all_parameters {
    my ($self) = @_;
    return grep $_->does('MR::Rest::Meta::Attribute::Trait::Parameter'), $self->get_all_attributes();
}

sub add_parameter_object {
    my ($self, $name, %args) = @_;
    $args{traits} = ['MR::Rest::Meta::Attribute::Trait::ParameterObject', $args{traits} ? @{$args{traits}} : ()];
    return $self->add_attribute($name => %args);
}

sub get_all_parameter_objects {
    my ($self) = @_;
    return grep $_->does('MR::Rest::Meta::Attribute::Trait::ParameterObject'), $self->get_all_attributes();
}

no Mouse::Role;

1;
