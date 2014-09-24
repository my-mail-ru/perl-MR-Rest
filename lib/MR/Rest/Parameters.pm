package MR::Rest::Parameters;

use Mouse;

use Encode;
use URI::Escape::XS;

has _env => (
    init_arg => 'env',
    is  => 'ro',
    isa => 'HashRef',
    required => 1,
);

has _path_params => (
    init_arg => 'path_params',
    is  => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

has _query_string_params => (
    init_arg => undef,
    is  => 'ro',
    isa => 'HashRef',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->_parse_urlencoded($self->_env->{QUERY_STRING});
    },
);

has _body_params => (
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

sub validate {
    my ($self) = @_;
    $self->meta->validator->($self);
    return;
}

sub _parse_urlencoded {
    my ($class, $data) = @_;
    return {
        map {
            my ($k, $v) = split /=/, $_, 2;
            foreach ($k, $v) {
                $_ = decode('UTF-8', decodeURIComponent($_));
                s/\+/ /g;
            }
            $k => $v;
        } split /&/, $data
    };
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
