package MR::Rest::Meta::Attribute::Trait::Parameter;

use Mouse::Role;

use MR::Rest::Type;

with 'MR::Rest::Meta::Trait::Doc';

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
        $args->{required} = 1 if $args->{in} eq 'path';
        if ($args->{in} eq 'header') {
            my $envname = "HTTP_\U$name";
            $args->{default} = sub { $_[0]->_env->{$envname} };
            unless (exists $args->{doc}) {
                $args->{doc} = $name;
                $args->{doc} =~ s/^(.)/\u$1/;
                $args->{doc} =~ s/_(.)/-\u$1/g;
            }
        } else {
            my $locattr = "_$args->{in}_params";
            $args->{default} = sub { $_[0]->$locattr->{$name} };
        }
    }
    $args->{isa} = "Maybe[$args->{isa}]" unless $args->{required};
    return;
};

no Mouse::Role;

1;
