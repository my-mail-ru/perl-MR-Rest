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

has _query_params => (
    init_arg => undef,
    is  => 'ro',
    isa => 'HashRef',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->_parse_urlencoded($self->_env->{QUERY_STRING});
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
                s/\+/ /g;
                $_ = decode('UTF-8', decodeURIComponent($_));
            }
            $k => $v;
        } split /&/, $data
    };
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
