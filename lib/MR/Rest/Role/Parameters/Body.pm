package MR::Rest::Role::Parameters::Body;

use Mouse::Role -traits => 'MR::Rest::Meta::Role::Trait::CanThrowResponse';

use File::Map;

use MR::Rest::Responses;
__PACKAGE__->meta->add_error('invalid_content_length');

has _read_bytes => (
    is  => 'rw',
    isa => 'Int',
    default => 0,
);

sub content_type {
    shift->_env->{CONTENT_TYPE};
}

sub content_length {
    shift->_env->{CONTENT_LENGTH};
}

sub read {
    my ($self, undef, $length, $offset) = @_;
    $length = 8192 unless defined $length;
    $offset = 0 unless defined $offset;
    my $read = $self->_env->{'psgi.input'}->read($_[1], $length, $offset);
    if (!defined $read) {
        confess "Failed to read from psgi.input";
    } elsif ($read == 0) {
        die $self->meta->responses->invalid_content_length unless $self->_read_bytes == $self->content_length;
    } else {
        my $total = $self->_read_bytes($self->_read_bytes + $read);
        die $self->meta->responses->invalid_content_length if $total > $self->content_length;
    }
    return $read;
}

sub slurp {
    my ($self, undef) = @_;
    File::Map::map_anonymous($_[1], $self->content_length, 'private');
    my $offset = 0;
    no warnings 'substr';
    while (my $read = $self->read(my $buf)) {
        substr $_[1], $offset, $read, $buf;
        $offset += $read;
    }
    return $offset;
}

no Mouse::Role;

1;
