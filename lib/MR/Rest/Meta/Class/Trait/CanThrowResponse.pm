package MR::Rest::Meta::Class::Trait::CanThrowResponse;

use Mouse::Role;

with 'MR::Rest::Meta::Role::Trait::CanThrowResponse';

has responses => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'MR::Rest::Type::ResponsesName',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $name = $self->name . '::Responses';
        Mouse->init_meta(for_class => $name);
        Mouse::Util::MetaRole::apply_metaroles(
            for => $name,
            class_metaroles => {
                class => ['MR::Rest::Meta::Class::Trait::Responses'],
            },
        );
        my $meta = $name->meta;
        my @responses;
        push @responses, map $_->_responses, grep $_->does('MR::Rest::Meta::Role::Trait::CanThrowResponse'), $self, @{$self->roles};
        push @responses, map $_->responses->meta->responses, grep $_->does('MR::Rest::Meta::Class::Trait::CanThrowResponse'), map $_->meta, $self->superclasses;
        foreach my $responses (@responses) {
            foreach my $name (keys %$responses) {
                $meta->add_response($name, $responses->{$name});
            }
        }
        return $name;
    },
);

no Mouse::Role;

1;
