package MR::Rest::Util::Parameters;

use Mouse::Exporter;
use MR::Rest::Meta::Role::Parameters;

Mouse::Exporter->setup_import_methods(
    as_is => [qw/ params /],
);

sub params {
    my ($name, %args) = @_ == 2 ? ($_[0], params => $_[1]) : @_;
    my $meta = Mouse::Role->init_meta(for_class => $name, metaclass => 'MR::Rest::Meta::Role::Parameters');
    Mouse::Util::apply_all_roles($meta, ref $args{also} eq 'ARRAY' ? @{$args{also}} : ($args{also})) if $args{also};
    foreach my $name (keys %{$args{params}}) {
        my $params = $args{params}->{$name};
        if (my $in = $args{in}) {
            $params = { isa => $params } unless ref $params;
            $params->{in} ||= $in;
        };
        $meta->add_parameter($name, $params);
    }
    foreach my $name (keys %{$args{objects}}) {
        $meta->add_parameter_object($name, %{$args{objects}->{$name}});
    }
    foreach my $name (keys %{$args{responses}}) {
        $meta->add_response($name, $args{responses}->{$name});
    }
    return $meta;
}

1;
