package MR::Rest::Config;

use Mouse;

use MR::Rest::Type;

has namespaces => (
    is  => 'ro',
    isa => 'ArrayRef[Str]',
    auto_deref => 1,
    required   => 1,
);

has service => (
    is  => 'ro',
    isa => 'ClassName',
    lazy    => 1,
    default => sub {
        require MR::Rest::Service;
        return 'MR::Rest::Service';
    },
);

has resource => (
    is  => 'ro',
    isa => 'ClassName',
    lazy    => 1,
    default => sub {
        require MR::Rest::Resource;
        return 'MR::Rest::Resource';
    },
);

has operation => (
    is  => 'ro',
    isa => 'ClassName',
    lazy    => 1,
    default => sub {
        require MR::Rest::Operation;
        return 'MR::Rest::Operation';
    },
);

has allow => (
    is  => 'ro',
    isa => 'Maybe[MR::Rest::Type::Config::Allow]',
    default => undef,
);

has field => (
    is  => 'ro',
    isa => 'Maybe[RoleName]',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return unless $self->allow;
        my $meta = Mouse::Role->init_meta(for_class => $self->namespaces->[0] . '::Meta::Attribute::Trait::Field');
        $meta->add_attribute('+allow' => isa => $self->allow);
        return $meta->name;
    },
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    $args{namespaces} = [ $args{namespace} ] if $args{namespace};
    return $class->$orig(\%args);
};

my %configs;
my $default;

sub BUILD {
    my ($self) = @_;
    foreach ($self->namespaces) {
        confess "Config for namespace %s already registered", $_ if $configs{$_};
        $configs{$_} = $self;
    }
    return;
}

sub find {
    my ($class, $name) = @_;
    while (1) {
        my $config = $configs{$name};
        return $config if $config;
        unless ($name =~ s/::[^:]+$//) {
           return $default ||= __PACKAGE__->new(namespaces => []);
        }
    }
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
