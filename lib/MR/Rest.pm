package MR::Rest;

use Mouse;
use Mouse::Exporter;
use Mouse::Util::MetaRole;
use MR::Rest::Meta::Controller;

Mouse::Exporter->setup_import_methods(
    as_is => [qw/ params result controller /],
    also  => 'Mouse',
);

sub init_meta {
    my ($class, %args) = @_;
    Mouse->init_meta(%args);
    Mouse::Util::MetaRole::apply_metaroles(
        for => $args{for_class},
        class_metaroles => {
            class => ['MR::Rest::Meta::Class::Trait::Controllers'],
        },
    );
    return $args{for_class}->meta();
}

sub params {
    caller->meta->add_parameters(@_ == 2 ? ($_[0] => params => $_[1]) : @_);
}

sub result {
    caller->meta->add_result(@_ == 2 ? ($_[0] => fields => $_[1]) : @_);
}

sub controller {
    caller->meta->add_controller(@_);
}

sub dispatch {
    shift;
    return MR::Rest::Meta::Controller->dispatch(@_);
}

sub controllers {
    shift;
    return MR::Rest::Meta::Controller->controllers(@_);
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
