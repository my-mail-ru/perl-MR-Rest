package MR::Rest::Meta::Attribute::Trait::Parameter;

use Mouse::Role;

use MR::Rest::Type;

with 'MR::Rest::Role::Doc';

has in => (
    is  => 'ro',
    isa => 'MR::Rest::Type::ParameterLocation',
    default => 'form',
);

before _process_options => sub {
    my ($class, $name, $args) = @_;
    if ($args->{in} eq 'body') {
        $args->{is} = 'bare';
    } else {
        $args->{is} = 'ro';
        $args->{lazy} = 1;
        my $locattr = "_$args->{in}_params";
        $args->{default} = sub { $_[0]->$locattr->{$name} };
    }
    return;
};

no Mouse::Role;

1;
