package MR::Rest::Service;

use Mouse;

use MR::Rest::Type;
use MR::Rest::Resource;

with 'MR::Rest::Role::Doc';

has name => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has version => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Version',
    default => '0.1',
);

has namespace => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub { 'MR::Rest::' . $_[0]->name },
);

has host => (
    is     => 'ro',
    writer => '_host',
    isa    => 'Str',
);

has base_path => (
    is      => 'ro',
    writer  => '_base_path',
    isa     => 'Str',
    default => '',
);

has resources => (
    init_arg   => undef,
    is         => 'ro',
    isa        => 'ArrayRef[MR::Rest::Resource]',
    auto_deref => 1,
    default    => sub { [] },
);

has _resources => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'HashRef[MR::Rest::Resource]',
    default  => sub { {} },
);

my %services;

sub BUILD {
    my ($self) = @_;
    confess sprintf "Service %s already exists", $self->name if $services{$self->name};
    $services{$self->name} = $self;
    return;
}

sub find {
    my ($class, $name) = @_;
    return $services{$name};
}

sub add_resource {
    my ($self, $resource) = @_;
    confess sprintf "Resource %s in service %s already registered", $resource->path, $self->name if $self->_resources->{$resource->path};
    confess sprintf "Resource %s in service %s already registered", $resource->name, $self->name if $self->_resources->{$resource->name};
    $self->_resources->{$resource->path} = $resource;
    $self->_resources->{$resource->name} = $resource;
    push @{$self->resources}, $resource;
    return;
}

sub resource {
    my ($self, $ident) = @_;
    return $self->_resources->{$ident};
}

sub install {
    my ($self, $host, $base_path) = @_;
    confess sprintf "Service %s already installed", $self->name if defined $self->host;
    $self->_host($host);
    $self->_base_path($base_path) if defined $base_path;
    $_->install() foreach $self->resources();
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
