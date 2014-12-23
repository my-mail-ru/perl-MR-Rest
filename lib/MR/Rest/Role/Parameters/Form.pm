package MR::Rest::Role::Parameters::Form;

use Mouse::Role -traits => 'MR::Rest::Meta::Role::Trait::CanThrowResponse';

use MR::Rest::Responses;
__PACKAGE__->meta->add_error('invalid_content_type');
__PACKAGE__->meta->add_error('content_length_required');
__PACKAGE__->meta->add_error('request_too_large');

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
        return $self->_parse_form($data);
    },
);

after validate => sub {
    my ($self) = shift;
    unless ($self->_env->{CONTENT_TYPE} eq 'application/x-www-form-urlencoded') {
        die $self->meta->responses->invalid_content_type;
    }
    unless (exists $self->_env->{CONTENT_LENGTH}) {
        die $self->meta->responses->content_length_required;
    }
    if ($self->_env->{CONTENT_LENGTH} > 1024 * 1024) {
        die $self->meta->responses->request_too_large;
    }
    $self->_form_params;
    return;
};

no Mouse::Role;

1;
