package MR::Rest::Meta::Attribute::Trait::Parameter;

use Mouse::Role;

use MR::Rest::Type;

with 'MR::Rest::Role::Doc';

has in => (
    is  => 'ro',
    isa => 'MR::Rest::Type::ParameterLocation',
    default => 'BODY',
);

my %LOCATTR = (
    PATH         => '_path_params',
    QUERY_STRING => '_query_string_params',
    BODY         => '_body_params',
);

before _process_options => sub {
    my ($class, $name, $args) = @_;
    $args->{is} = 'ro';
    $args->{lazy} = 1;
    my $locattr = $LOCATTR{$args->{in} || 'BODY'};
    $args->{default} = sub { $_[0]->$locattr->{$name} };
    return;
};

no Mouse::Role;

1;
