package MR::Rest::Meta::Role::Trait::Result;

use Mouse::Role;

has list => (
    is  => 'rw',
    isa => 'Bool',
    default => 0,
);

has hashby => (
    is  => 'rw',
    isa => 'Maybe[Str]',
    default => undef,
);

has field_traits => (
    is  => 'rw',
    isa => 'ArrayRef[RoleName]',
    default => sub { [] },
);

sub add_field {
    my $self = shift;
    my $name = shift;
    my %args = @_ != 1 ? @_
        : !ref $_[0] ? (isa => $_[0])
        : ref $_[0] eq 'HASH' ?
            keys %{$_[0]} == 1 && (keys %{$_[0]})[0] =~ /^(?:(.+):|\*)$/
                ? (hashby => $1, isa => do { my ($v) = values %{$_[0]}; $v = MR::Rest::Util::Result::result(fields => $v, field_traits => $self->field_traits)->name if ref $v; "HashRef[$v]" })
                : %{$_[0]}
        : ref $_[0] eq 'ARRAY' && @{$_[0]} == 1 ? (isa => do { my $v = $_[0][0]; $v = MR::Rest::Util::Result::result(fields => $v, field_traits => $self->field_traits)->name if ref $v; "ArrayRef[$v]" })
        : ();
    if (exists $args{isa}) {
        $args{traits} = ['MR::Rest::Meta::Attribute::Trait::Field', @{$self->field_traits}, $args{traits} ? @{$args{traits}} : ()];
        return $self->add_attribute($name => %args);
    } else {
        $self->add_field("$name.$_", $args{$_}) foreach keys %args;
    }
}

sub get_all_fields {
    my ($self) = @_;
    return grep $_->does('MR::Rest::Meta::Attribute::Trait::Field'), $self->get_all_attributes();
}

no Mouse::Role;

1;
