package MR::Rest::Meta::Class::Trait::Parameters;

use Mouse::Role;

use MR::Rest::Error;

has validator => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $has_body = grep { $_->location eq 'BODY' } $_[0]->get_all_parameters();
        my @parameters = map $_->name, $self->get_all_parameters();
        return sub {
            my ($self) = @_;
            if ($has_body) {
                unless ($self->_env->{CONTENT_TYPE} eq 'application/x-www-form-urlencoded') {
                    die MR::Rest::Error->new(415, 'invalid_content_type', "Content-Type should be 'application/x-www-form-urlencoded'");
                }
                unless (exists $self->_env->{CONTENT_LENGTH}) {
                    die MR::Rest::Error->new(411, 'length_required', "Content-Length Required");
                }
                if ($self->_env->{CONTENT_LENGTH} > 1024 * 1024) {
                    die MR::Rest::Error->new(413, 'request_too_large', "Content-Length should be less then 1Mb");
                }
                $self->_body_params;
            }
            my @invalid;
            foreach my $param (@parameters) {
                push @invalid, $param unless eval { $self->$param; 1 };
            }
            die MR::Rest::Error->new(400, 'invalid_param', sprintf("Invalid parameter%s: %s", @invalid > 1 ? 's' : '', join ', ', @invalid)) if @invalid;
            return;
        };
    },
);

sub add_parameter {
    my ($class, $name, %args) = @_;
    return $class->add_attribute(
        $name  => %args,
        traits => ['MR::Rest::Meta::Attribute::Trait::Parameter'],
    );
}

sub get_all_parameters {
    my ($self) = @_;
    return grep $_->does('MR::Rest::Meta::Attribute::Trait::Parameter'), $self->get_all_attributes();
}

no Mouse::Role;

1;
