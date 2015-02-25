package MR::Rest::Meta::Attribute::Trait::Parameter;

use Mouse::Role;

use MR::Rest::Type;

with 'MR::Rest::Role::Doc';

has in => (
    is  => 'ro',
    isa => 'MR::Rest::Type::ParameterLocation',
    default => 'form',
);

has hidden => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
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
            my $envname = $name =~ /^content_(?:type|length)$/ ? "\U$name" : "HTTP_\U$name";
            my $t = Mouse::Util::TypeConstraints::find_or_parse_type_constraint($args->{isa});
            $args->{default} = $t->is_a_type_of('Object') ? do {
                my $c = $t->name;
                sub {
                    my $v = $_[0]->_env->{$envname};
                    defined $v && length $v ? $c->new($v) : undef;
                };
            } : $t->is_a_type_of('ArrayRef') ? do {
                $t->type_parameter && $t->type_parameter->is_a_type_of('Object') ? do {
                        my $c = $t->type_parameter->name;
                        sub {
                            my $v = $_[0]->_env->{$envname};
                            defined $v ? [ map $c->new($_), map { s/^\s+|\s+$//g; $_ } split /,/, $v ] : [];
                        };
                    } : sub {
                        my $v = $_[0]->_env->{$envname};
                        defined $v ? [ map { s/^\s+|\s+$//g; $_ } split /,/, $v ] : [];
                    }
            } : sub {
                my $v = $_[0]->_env->{$envname};
                defined $v && length $v ? $v : undef;
            };
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
