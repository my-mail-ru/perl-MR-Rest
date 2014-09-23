package MR::Rest::Meta::Attribute::Trait::Field;

use Mouse::Role;

with 'MR::Rest::Role::Doc';

has accessor => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub { (split /\./, $_[0]->name)[-1] },
);

has hashby => (
    is  => 'ro',
    isa => 'Maybe[Str]',
    default => undef,
);

before _process_options => sub {
    my ($class, $name, $args) = @_;
    $args->{is} = 'ro';
    return;
};

no Mouse::Role;

1;
