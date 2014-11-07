package MR::Rest::Response;

use Mouse;

use HTTP::Headers;
use MR::Rest::Type;

with 'MR::Rest::Role::Response';

my @headers_handles = qw/
    content_type
    content_length
/;

has status => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Status',
    lazy    => 1,
    default => 200,
);

has headers => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Headers',
    coerce  => 1,
    default => sub { HTTP::Headers->new() },
    handles => \@headers_handles,
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    if (my @headers = map { exists $args{$_} ? ($_ => delete $args{$_}) : () } @headers_handles) {
        if (!$args{headers}) {
            $args{headers} = HTTP::Headers->new();
        } elsif (ref $args{headers} eq 'HASH') {
            $args{headers} = HTTP::Headers->new(%{$args{headers}});
        } elsif (ref $args{headers} eq 'ARRAY') {
            $args{headers} = HTTP::Headers->new(@{$args{headers}});
        }
        $args{headers}->header(@headers);
    }
    return $class->$orig(\%args);
};

sub render {
    my ($self, %args) = @_;
    my $body = $self->_plain_body(%args);
    my $status = $self->status;
    if ($status >= 200 && $status != 204 && $status != 304) {
        if (blessed $body) {
            confess "Content-Length is required if body is passed as a handle"
                unless $self->content_length;
        } else {
            my $length = 0;
            $length += length $_ foreach @$body;
            $self->content_length($length);
        }
    }
    return [ $status, $self->_plain_headers(), $body ];
}

sub _plain_headers {
    my $headers = $_[0]->headers;
    return [ map { my $h = $_; map { $h => $_ } $headers->header($_) } $headers->header_field_names ];
}

sub _plain_body {
    [];
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
