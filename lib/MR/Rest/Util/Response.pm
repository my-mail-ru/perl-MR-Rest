package MR::Rest::Util::Response;

use Mouse::Exporter;
use Carp qw/confess/;

use MR::Rest::Response::Error;
use MR::Rest::Meta::Response;

Mouse::Exporter->setup_import_methods(
    as_is => [qw/ response common_response error_response where_throw_error /],
);

sub response {
    my ($name, %args) = @_;
    $args{name} = $name;
    return MR::Rest::Meta::Response->new(\%args);
}

sub common_response {
    my ($name, %args) = @_;
    $args{name} = MR::Rest::Meta::Response->common_name($name);
    return MR::Rest::Meta::Response->new(\%args);
}

sub error_response {
    my ($name, $status, $doc, %errargs);
    if (@_ == 3) {
        ($name, $status, my $desc) = @_;
        $errargs{error} = $name;
        $errargs{error_description} = $desc if defined $desc;
    } else {
        ($name, my %args) = @_;
        $status = $args{status};
        $errargs{error} = $name;
        $errargs{error_description} = $args{desc} if defined $args{desc};
        $errargs{error_uri} = $args{uri} if defined $args{uri};
        $doc = $args{doc};
    }
    $name = MR::Rest::Meta::Response->error_name($name);
    return response $name => (
        isa    => 'MR::Rest::Response::Error',
        status => $status || 400,
        args   => \%errargs,
        $doc ? (doc => $doc) : (),
    );
}

sub where_throw_error (&$) {
    my ($check, $name) = @_;
    my $response = MR::Rest::Meta::Response->error($name) or confess "Error not found: $name";
    my $sub = $response->response_sub;
    return (
        Mouse::Util::TypeConstraints::where { $check->() ? 1 : die $sub->() },
        Mouse::Util::TypeConstraints::message { $sub->() },
    );
}

1;
