package MR::Rest::Error;

use Mouse;

with 'MR::Rest::Role::Response';

has '+status' => (
    default => 400,
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    if (!ref $_[0] && $_[0] =~ /^\d{3}$/) {
        my %args;
        @args{qw/ status error error_description error_uri/} = @_;
        return $class->$orig(\%args);
    } else {
        return $class->$orig(@_);
    }
};

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
