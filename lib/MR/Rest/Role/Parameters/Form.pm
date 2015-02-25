package MR::Rest::Role::Parameters::Form;

use Mouse::Role -traits => 'MR::Rest::Meta::Role::Trait::Parameters';

use MR::Rest::Header::Parameterized;
__PACKAGE__->meta->add_parameter(content_type => { in => 'header', isa => 'MR::Rest::Header::Parameterized', hidden => 1 });
__PACKAGE__->meta->add_parameter(content_length => { in => 'header', isa => 'Int', hidden => 1 });

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
    if (!defined $self->content_length) {
        die $self->meta->responses->content_length_required;
    } elsif ($self->content_length) {
        unless ($self->content_type && $self->content_type->value eq 'application/x-www-form-urlencoded') {
            die $self->meta->responses->invalid_content_type;
        }
        if ($self->content_length > 1024 * 1024) {
            die $self->meta->responses->request_too_large;
        }
    }
    $self->_form_params;
    return;
};

no Mouse::Role;

1;
