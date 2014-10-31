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

has '+body' => (
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $data = $self->schema->meta->transformer->($self->root, $self->access_roles);
        return JSON::XS::encode_json($data);
    }
);

sub root { shift }

no Mouse::Role;

1;
