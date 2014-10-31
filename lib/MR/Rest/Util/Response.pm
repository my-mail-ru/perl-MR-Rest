package MR::Rest::Util::Response;

use Mouse::Exporter;

use MR::Rest::Response::Error;
use MR::Rest::Meta::Response;

Mouse::Exporter->setup_import_methods(
    as_is => [qw/ response error_response /],
);

sub response {
    my ($name, %args) = @_;
    $args{name} = $name;
    return MR::Rest::Meta::Response->new(\%args);
}

sub error_response {
    my ($name, $status, $desc, $uri) = @_;
    my %args;
    $args{error} = $name;
    $args{error_description} = $desc if defined $desc;
    $args{error_uri} = $uri if defined $uri;
    $name = MR::Rest::Meta::Response->error_name($name);
    return response $name => (
        isa    => 'MR::Rest::Response::Error',
        status => $status,
        args   => \%args,
    );
}

1;
