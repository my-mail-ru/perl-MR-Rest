package MR::Rest::Meta::Attribute::Trait::Field;

use Mouse::Role;

use MR::Rest::Type;

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

has allow => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Allow',
    coerce  => 1,
    default => sub { [ 'all' ] },
);

before _process_options => sub {
    my ($class, $name, $args) = @_;
    $args->{is} = 'ro';
    $args->{required} = $args->{allow} ? ref $args->{allow} ? grep { $_ eq 'all' } @{$args->{allow}} > 0 : $args->{allow} eq 'all' : 1 unless exists $args->{required};
    return;
};

no Mouse::Role;

1;
