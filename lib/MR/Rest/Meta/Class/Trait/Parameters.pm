package MR::Rest::Meta::Class::Trait::Parameters;

use Mouse::Role;

use URI::Escape::XS;

with 'MR::Rest::Meta::Role::Trait::Parameters';

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

has uri_formatter => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my @path = map $_->name, grep { $_->in eq 'path' } $_[0]->get_all_parameters();
        my $path_str = join '|', map "\Q$_\E", @path;
        my $path_re = qr/\{($path_str)\}/;
        my @query = map $_->name, grep { $_->in eq 'query' } $_[0]->get_all_parameters();
        return sub {
            my ($path, $params) = @_;
            foreach my $name (@path) {
                confess "Parameter '$name' is required" unless defined $params->{$name};
            }
            $path =~ s/$path_re/encodeURIComponent($params->{$1})/ge;
            my @qs;
            foreach my $name (@query) {
                push @qs, join '=', encodeURIComponent($name), encodeURIComponent($params->{$name}) if defined $params->{$name};
            }
            $path .= '?' . join '&', @qs if @qs;
            return $path;
        };
    },
);

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
    $self->validator;
    $self->uri_formatter;
    return;
};

no Mouse::Role;

1;
