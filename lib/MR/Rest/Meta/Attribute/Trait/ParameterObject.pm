package MR::Rest::Meta::Attribute::Trait::ParameterObject;

use Mouse::Role;

with 'MR::Rest::Meta::Trait::Doc';

has param => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has key => (
    is  => 'ro',
    isa => 'Str',
);

has to_object => (
    is  => 'ro',
    isa => 'CodeRef',
    required => 1,
);

before _process_options => sub {
    my ($class, $name, $args) = @_;
    $args->{is} = 'ro';
    if (my $to_object = $args->{to_object}) {
        confess "You can not use to_object and (lazy_build, default or builder) for the same attribute ($name)"
            if exists $args->{lazy_build} || exists $args->{default} || exists $args->{builder};
        $args->{lazy} = 1;
        my $param_name = $args->{param};
        $args->{default} = sub {
            local $_ = $_[0]->$param_name;
            return $_[0]->$to_object($_);
        };
    }
    return;
};

no Mouse::Role;

1;
