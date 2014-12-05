package MR::Rest::Util::Result;

use Mouse::Exporter;
use MR::Rest::Config;
use MR::Rest::Meta::Class::Result;

Mouse::Exporter->setup_import_methods(
    as_is => [qw/ result /],
);

my $ANON_SERIAL = 0;

sub result {
    my ($name, %args) = @_ == 2 ? ($_[0] => fields => $_[1]) : @_;
    my $config = MR::Rest::Config->find(scalar caller);
    $args{field_traits} ||= [ $config->field ] if $config && $config->field;
    $name = sprintf "MR::Rest::Result::__ANON__::%s", ++$ANON_SERIAL unless defined $name;

    my $rolemeta = MR::Rest::Meta::Role::Result->initialize("${name}::Role");
    Mouse::Util::apply_all_roles($rolemeta, map $_->rolemeta, ref $args{also} eq 'ARRAY' ? @{$args{also}} : ($args{also})) if $args{also};
    $rolemeta->field_traits($args{field_traits}) if $args{field_traits};
    $rolemeta->add_field($_ => $args{fields}->{$_}) foreach keys %{$args{fields}};

    my $meta = Mouse->init_meta(metaclass => 'MR::Rest::Meta::Class::Result', for_class => $name);
    Mouse::Util::apply_all_roles($meta, $rolemeta);
    $meta->doc($args{doc}) if $args{doc};
    $meta->field_traits($args{field_traits}) if $args{field_traits};
    $meta->add_method(rolemeta => sub { $rolemeta });
    $meta->add_method(transform => $meta->transformer);
    return $meta;
}

1;
