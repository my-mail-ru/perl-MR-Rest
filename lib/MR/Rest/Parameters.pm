package MR::Rest::Parameters;

use Mouse -traits => 'MR::Rest::Meta::Class::Trait::Parameters';

use MR::Rest::Responses;
__PACKAGE__->meta->add_error('invalid_param');

has _env => (
    init_arg => 'env',
    is  => 'ro',
    isa => 'HashRef',
    required => 1,
);

has _path_params => (
    init_arg => 'path_params',
    is  => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

has _query_params => (
    init_arg => undef,
    is  => 'ro',
    isa => 'HashRef',
    lazy    => 1,
    default => sub { $_[0]->_parse_query($_[0]->_env->{QUERY_STRING}) },
);

sub validate {
    my ($self) = @_;
    $self->meta->validator->($self);
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
