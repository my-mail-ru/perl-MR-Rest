package MR::Rest::Response::Error;

use Mouse;

use MR::Rest::Util::Result;
result 'MR::Rest::Response::Error::Result' => (
    fields => {
        error => {
            isa => 'Str',
            doc => 'A single error code, used by client to identify distinct error type',
        },
        error_description => {
            isa => 'Str',
            required => 0,
            doc => 'Human-readable UTF-8 text providing additional information, used to assist the client developer in understanding the error that occurred',
        },
        error_uri => {
            isa => 'Str',
            required => 0,
            doc => 'A URI identifying a human-readable web page with information about the error, used to provide the client developer with additional information about the error',
        },
    },
    doc => 'Generic error object',
);
no MR::Rest::Util::Result;

extends 'MR::Rest::Response';
with 'MR::Rest::Role::Response::JSON';

has error => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Error',
);

has error_description => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

has error_uri => (
    is  => 'ro',
    isa => 'Maybe[Str]',
);

has '+schema' => (default => 'MR::Rest::Response::Error::Result');

has '+status' => (default => 400);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    if (!ref $_[0] && $_[0] =~ /^\d{3}$/) {
        my %args;
        @args{qw/ status error error_description error_uri/} = @_;
        return $class->$orig(\%args);
    } else {
        my %args = @_ == 1 ? %{$_[0]} : @_;
        if (my $args = delete $args{args}) {
            $args{error_description} = sprintf $args{error_description}, @$args;
            return $class->$orig(%args);
        } else {
            return $class->$orig(@_);
        }
    }
};

no Mouse;
__PACKAGE__->meta->make_immutable();

*MR::Rest::Error:: = \*MR::Rest::Response::Error::;

1;
