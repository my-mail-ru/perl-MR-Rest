package MR::Rest::Meta::Response;

use Mouse;

use MR::Rest::Type;
use MR::Rest::Response::Item;
use MR::Rest::Util::Result ();

with 'MR::Rest::Role::Doc';

has '+doc' => (
    lazy    => 1,
    default => sub { $_[0]->class->isa('MR::Rest::Response::Error') ? $_[0]->args->{error_description} : undef },
);

has name => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has status => (
    is  => 'ro',
    isa => 'Int',
    default => 200,
);

has class => (
    init_arg => 'isa',
    is       => 'ro',
    isa      => 'ClassName',
    default  => 'MR::Rest::Response::Item',
);

has schema => (
    is     => 'ro',
    writer => '_schema',
    isa    => 'MR::Rest::Type::ResultName | HashRef',
);

has args => (
    is  => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

has response_sub => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $isa = $self->class;
        my %args = (%{$self->args}, status => $self->status);
        my $schema_attr = $isa->meta->get_attribute('schema');
        my $default = $schema_attr ? $schema_attr->default() : undef;
        if (my $schema = $self->schema) {
            if (ref $schema eq 'HASH') {
                my %args = exists $schema->{fields} ? %$schema : (fields => $schema);
                $args{also} = [ $args{also} ? ref $args{also} ? @{$args{also}} : $args{also} : (), $default ] if $default;
                $schema = MR::Rest::Util::Result::result($self->name, %args)->name;
                $self->_schema($schema);
            }
            confess "Incompatible schema: $schema" if $default && !$schema->does($default->role);
            $args{schema} = $schema;
        } elsif ($default) {
            $self->_schema($default);
        }
        my %mutable = map { $_->name => delete $args{$_->name} } grep { $args{$_->name} && $_->has_accessor } $isa->meta->get_all_attributes();
        return sub { shift; $isa->new(%mutable, @_, %args) };
    },
);

my %responses;

sub BUILD {
    my ($self) = @_;
    my $name = $self->name;
    confess "Duplicate response: $name" if $responses{$name};
    $responses{$name} = $self;
    $self->response_sub;
    return;
}

sub responses {
    \%responses;
}

sub response {
    my ($class, $name) = @_;
    return $responses{$name};
}

sub error {
    my ($class, $name) = @_;
    return $class->response($class->error_name($name));
}

sub error_name {
    my ($class, $name) = @_;
    $name =~ s/(?:^|_)(.)/\u$1/g;
    return "MR::Rest::Response::Error::$name";
}

sub common_name {
    my ($class, $name) = @_;
    $name =~ s/(?:^|_)(.)/\u$1/g;
    return "MR::Rest::Response::Common::$name";
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
