package MR::Rest::Role::Parameters::Form;

use Mouse::Role;

has _form_params => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'HashRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $input = $self->_env->{'psgi.input'};
        my $read;
        my $data = '';
        while ($read = $input->read(my $buf, 1024)) {
            $data .= $buf;
        }
        confess "Failed to read from input stream" unless defined $read;
        # TODO check content-length, wait until all data is available
        return $self->_parse_urlencoded($data);
    },
);

no Mouse::Role;

1;
