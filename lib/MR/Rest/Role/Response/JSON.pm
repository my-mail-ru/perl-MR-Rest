package MR::Rest::Role::Response::JSON;

use Mouse::Role;

use JSON::XS;

use MR::Rest::Type;

has schema => (
    is  => 'ro',
    isa => 'MR::Rest::Type::ResultName',
    required => 1,
);

has '+headers' => (
    default => sub { [ 'Content-Type' => 'application/json' ] },
);

override _plain_body => sub {
    my ($self, %args) = @_;
    confess "access_roles omitted" unless $args{access_roles};
    my $data = $self->schema->meta->transformer->($self->root, $args{access_roles});
    return [ JSON::XS::encode_json($data) ];
};

sub root { shift }

no Mouse::Role;

1;
