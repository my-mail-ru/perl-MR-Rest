package MR::Rest;

use Mouse;
use Mouse::Exporter;
use Mouse::Util::MetaRole;
use MR::Rest::Config;
use MR::Rest::Service;
use MR::Rest::Resource;
use MR::Rest::Operation;
use MR::Rest::Util::Parameters ();
use MR::Rest::Util::Result ();
use MR::Rest::Util::Response ();

Mouse::Exporter->setup_import_methods(
    as_is => [qw/ service doc resource operation controller /],
    also  => ['Mouse', 'MR::Rest::Util::Parameters', 'MR::Rest::Util::Result', 'MR::Rest::Util::Response'],
);

my ($current_service, $current_resource);

sub service {
    my ($name, %args) = @_;
    my $service = MR::Rest::Service->find($name);
    if (!$service || %args) {
        my $config = MR::Rest::Config->find(scalar caller);
        $service = $config->service->new(%args, name => $name);
    }
    $current_service = $service;
    return $service;
}

sub resource {
    my ($path, %args) = @_;
    $args{service} ||= $current_service;
    $args{path} = $path;
    $args{in_package} ||= caller;
    my $config = MR::Rest::Config->find($args{in_package});
    my $resource = $config->resource->new(\%args);
    $current_resource = $resource;
    return $resource;
}

sub operation {
    my ($method, %args) = @_;
    $args{resource} ||= $current_resource;
    $args{method} = $method;
    my $config = MR::Rest::Config->find(scalar caller);
    return $config->operation->new(\%args);
}

# Old API compatibility
sub controller {
    my ($name, %args) = @_;
    my ($method, $path) = split / /, $name, 2;
    confess "Invalid controller declaration: it should be in form 'METHOD /resource/uri'" unless $path;
    my $service = delete $args{service} || $current_service;
    my $resource = $service->resource($path) || MR::Rest::Resource->new(service => $service, path => $path, in_package => scalar caller);
    @_ = ($method, %args, resource => $resource);
    goto &operation;
}

sub dispatch {
    my ($class, $env) = @_;
    my $path_var = MR::Rest::Config->find($class)->path_var;
    my $path_encoded = $path_var eq 'REQUEST_URI';
    my $path = $env->{$path_var};
    $path =~ s/\?.*$// if $path_encoded;
    my ($resource, $path_params) = MR::Rest::Resource->find($env->{HTTP_HOST}, $path, $path_encoded);
    return [ 404 ] unless $resource;
    my $operation = $resource->operation($env->{REQUEST_METHOD})
        or return [ 405, [ Allow => join ', ', map $_->method, $resource->operations() ] ];
    return $operation->process($env, $path_params);
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
