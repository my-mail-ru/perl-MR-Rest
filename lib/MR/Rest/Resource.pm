package MR::Rest::Resource;

use Mouse;

use Encode;
use URI::Escape::XS;

use MR::Rest::Type;
use MR::Rest::Util::Parameters;

has service => (
    is  => 'ro',
    isa => 'MR::Rest::Service',
    required => 1,
    weak_ref => 1,
);

has path => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Path',
    required => 1,
);

has name => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $path = $self->path;
        my (undef, @chunks) = split /\//, $path;
        push @chunks, 'list' if $path =~ /\/$/;
        my $name = lc join '_', map { /^\{.*\}$/ ? 'item' : $_ } @chunks;
        $name =~ s/[^a-z0-9_]/_/g;
        return $name;
    },
);

has namespace => (
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $name = $self->name;
        $name =~ s/(?:^|_)(.)/\u$1/g;
        return $self->service->namespace . '::' . $name;
    },
);

has in_package => (
    is  => 'ro',
    isa => 'ClassName',
    required => 1,
);

has owner => (
    is  => 'ro',
    isa => 'MR::Rest::Type::Resource::Owner',
    coerce => 1,
);

has operations => (
    init_arg   => undef,
    is         => 'ro',
    isa        => 'ArrayRef[MR::Rest::Operation]',
    auto_deref => 1,
    default    => sub { [] },
);

has _operations => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'HashRef[MR::Rest::Operation]',
    default  => sub { {} },
);

has _path_params => (
    init_arg => undef,
    is  => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

has _params => (
    init_arg => 'params',
    is  => 'ro',
    isa => 'HashRef | RoleName',
    default => sub { {} },
);

has params_role => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'Maybe[RoleName]',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $params = $self->_params;
        return unless $params;
        return $params unless ref $params;
        my $meta = MR::Rest::Util::Parameters::params($self->namespace . '::Parameters', in => 'path', %$params);
        return $meta->name;
    },
);

my %route;

sub BUILD {
    my ($self) = @_;
    $self->service->add_resource($self);
    $self->params_role;
    $self->install() if defined $self->service->host;
    return;
}

sub install {
    my ($self) = @_;

    my $current = $route{$self->service->host} ||= {};
    if (my $re = $self->service->host_regexp) {
        confess "Different host_regexp for the same host"
            if defined $current->{'{r}'} && $current->{'{r}'} ne $re;
        $current->{'{r}'} ||= $re;
    }

    my (undef, @base) = split /\//, $self->service->base_path;
    $current = $current->{$_} ||= {} foreach @base;
    my $pos = @base;

    my $path = $self->path;
    my (undef, @chunks) = split /\//, $path;
    my $params = $self->_path_params;
    foreach my $chunk (@chunks) {
        if ($chunk =~ /^\{(.*)\}$/) {
            $params->[$pos] = $1;
            $current = $current->{'{}'} ||= {};
        } else {
            $current = $current->{$chunk} ||= {};
        }
        $pos++;
    }
    my $key = $path =~ /\/$/ ? '{/}' : '{-}';
    confess "Resource already exists: $path" if $current->{$key};
    $current->{$key} = $self;
    return;
}

sub find {
    my ($class, $host, $path, $path_encoded) = @_;

    my $current = $route{$host};
    unless ($current) {
        foreach my $r (values %route) {
            my $re = $r->{'{r}'} or next;
            if ($host =~ $re) {
                $current = $r;
                last;
            }
        }
    }
    return unless $current;

    my @params;
    my (undef, @chunks) = split /\//, $path;
    if ($path_encoded) {
        $_ = decodeURIComponent($_) foreach @chunks;
    }
    $_ = decode('UTF-8', $_) foreach @chunks;
    foreach my $i (0 .. $#chunks) {
        if (my $next = $current->{$chunks[$i]}) {
            $current = $next;
        } else {
            $params[$i] = $chunks[$i];
            $current = $current->{'{}'}
                or return;
        }
    }
    my $key = $path =~ /\/$/ ? '{/}' : '{-}';
    my $resource = $current->{$key}
        or return;
    my $paramnames = $resource->_path_params;
    return unless @$paramnames == @params;
    my %params;
    foreach my $i (0 .. $#$paramnames) {
        return if defined $params[$i] xor defined $paramnames->[$i];
        if (defined $paramnames->[$i]) {
            $params{$paramnames->[$i]} = $params[$i];
        }
    }
    return ($resource, \%params);
}

sub add_operation {
    my ($self, $op) = @_;
    confess sprintf "Operation %s for resource %s already registered", $op->method, $self->path if $self->_operations->{$op->method};
    $self->_operations->{$op->method} = $op;
    push @{$self->operations}, $op;
    return;
}

sub operation {
    my ($self, $method) = @_;
    return $self->_operations->{$method};
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
