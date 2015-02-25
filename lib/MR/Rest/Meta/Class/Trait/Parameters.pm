package MR::Rest::Meta::Class::Trait::Parameters;

use Mouse::Role;

use Encode ();
use URI::Escape::XS ();

with 'MR::Rest::Meta::Role::Trait::Parameters';
with 'MR::Rest::Meta::Class::Trait::CanThrowResponse';

has validator => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my @parameters = map $_->name, grep { $_->in ne 'body' } $self->get_all_parameters();
        return sub {
            my ($self) = @_;
            my @invalid;
            foreach my $param (@parameters) {
                unless (eval { $self->$param; 1 }) {
                    my $e = $@;
                    die $e if blessed $e && $e->does('MR::Rest::Role::Response');
                    push @invalid, $param;
                }
            }
            die $self->meta->responses->invalid_param(error_description => sprintf "Invalid parameter%s: %s", @invalid > 1 ? 's' : '', join ', ', @invalid) if @invalid;
            return;
        };
    },
);

sub _urlencoded_parser {
    my ($self, $in) = @_;
    my %type = map {
        my $t = $_->type_constraint;
        my $p = $t->is_a_type_of('Maybe') ? $t->type_parameter : $t;
        $_->name => $p->is_a_type_of('MR::Rest::Type::CSV') ? 'csv'
            : $p->is_a_type_of('ArrayRef') ? 'array'
            : $p->is_a_type_of('Bool') ? 'bool'
            : $p->is_a_type_of('MR::Rest::Type::Binary') ? 'bin'
            : 'str'
    } grep { $_->in eq $in } $self->get_all_parameters();
    return sub {
        my ($self, $data) = @_;
        my %params;
        $data =~ s/\+/ /g;
        foreach (split /&/, $data) {
            my ($k, $v) = split /=/, $_, 2;
            $_ = URI::Escape::XS::decodeURIComponent($_) foreach ($k, $v);
            $k = Encode::decode('UTF-8', $k);
            my $t = $type{$k} or next;
            if ($t eq 'bin') {
                $params{$k} = $v;
            } else {
                $v = Encode::decode('UTF-8', $v);
                if ($t eq 'str') {
                    $params{$k} = $v;
                } elsif ($t eq 'bool') {
                    $params{$k} = $v eq 'true' ? 1 : $v eq 'false' ? 0 : \undef;
                } elsif ($t eq 'array') {
                    push @{$params{$k}}, $v;
                } elsif ($t eq 'csv') {
                    push @{$params{$k}}, map { s/^\s+|\s+$//g; $_ } split /,/, $v;
                }
            }
        }
        return \%params;
    };
}

before make_immutable => sub {
    my ($self) = @_;
    my ($has_form, $has_body);
    foreach my $param ($self->get_all_parameters()) {
        if ($param->in eq 'form') {
            $has_form = 1;
        } elsif ($param->in eq 'body') {
            $has_body = 1;
        }
    }
    confess "form and body parameters can't be used at the same time" if $has_form && $has_body;
    Mouse::Util::apply_all_roles($self->name, 'MR::Rest::Role::Parameters::Form') if $has_form;
    Mouse::Util::apply_all_roles($self->name, 'MR::Rest::Role::Parameters::Body') if $has_body;
    $self->add_method('_parse_query' => $self->_urlencoded_parser('query'));
    $self->add_method('_parse_form' => $self->_urlencoded_parser('form')) if $has_form;
    $self->validator;
    return;
};

no Mouse::Role;

1;
