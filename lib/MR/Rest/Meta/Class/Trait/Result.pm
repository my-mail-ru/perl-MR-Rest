package MR::Rest::Meta::Class::Trait::Result;

use Mouse::Role;

use MR::Rest::Type;

with 'MR::Rest::Meta::Role::Trait::Result';

has transformer_code => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my @code;
        foreach my $cond ('if ($blessed)', 'else') {
            push @code, "$cond {";
            foreach my $field ($self->get_all_fields()) {
                my $name = $field->name;
                my $rkey = join '', map "{$_}", split /\./, $name;
                my $dkey = $cond eq 'else' ? $rkey : $field->accessor;
                my $result = "\$result$rkey";
                my $value = "\$_->$dkey";
                my $allow = @{$field->allow} == 0 ? 0
                    : grep({ $_ eq 'all' } @{$field->allow}) ? 1
                    : join(' || ', map "\$roles->$_", @{$field->allow});
                push @code, "if ($allow) {";
                my $type = $field->type_constraint;
                if ($type->is_a_type_of('Num')) {
                    push @code, "$result = 0 + $value;";
                } elsif ($type->is_a_type_of('Str')) {
                    my $strval = $cond eq 'else' ? "\"$value\"" : "'' . $value";
                    push @code, "$result = $strval;";
                } elsif ($type->is_a_type_of('Bool')) {
                    push @code, "$result = $value ? \\1 : \\0;";
                } elsif ($type->is_a_type_of('Maybe')) {
                    my $param = $type->type_parameter;
                    if ($param->is_a_type_of('Num')) {
                        push @code, "my \$v = $value; $result = defined \$v ? 0 + \$v : undef;";
                    } elsif ($param->is_a_type_of('Str')) {
                        push @code, "my \$v = $value; $result = defined \$v ? \"\$v\" : undef;";
                    } elsif ($param->is_a_type_of('Bool')) {
                        push @code, "my \$v = $value; $result = defined \$v ? \$v ? \\1 : \\0 : undef;";
                    }
                } elsif ($type->is_a_type_of('ArrayRef')) {
                    my $code = $type->type_parameter->name->meta->transformer_code;
                    push @code, "\@{$result} = map { $code } \@{$value};";
                } elsif ($type->is_a_type_of('HashRef')) {
                    my $code = $type->type_parameter->name->meta->transformer_code;
                    if (my $hashby = $field->hashby) {
                        push @code, "\%{$result} = map { \$_->{$hashby} => \$_ } map { $code } \@{$value};"
                    } else {
                        push @code, "my \$h = $value; \%{$result} = map { \$_ => do { local \$_ = \$h->{\$_}; $code } } keys \%\$h;";
                    }
                }
                push @code, '}';
            }
            push @code, '}';
        }
        my $hashby = $self->hashby;
        return $self->list ? "my \@result; my \$blessed = blessed \$_->[0]; foreach (\@\$_) { my \%result; @code push \@result, \\\%result; } \\\@result;"
            : $hashby ? "my \%hashby; my \$blessed = blessed \$_->[0]; foreach (\@\$_) { my \%result; @code \$hashby{\$blessed ? \$_->$hashby : \$_->{$hashby}} = \\\%result; } \\\%hashby;"
            : defined $hashby ? "my \$in = \$_; my \%hashby; my \$blessed = blessed((values \%\$in)[0]); foreach my \$k (keys \%\$in) { local \$_ = \$in->{\$k}; my \%result; @code \$hashby{\$k} = \\\%result; } \\\%hashby;"
            : "my \%result; my \$blessed = blessed \$_; @code \\\%result;";
    },
);

has transformer => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'CodeRef',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my $name = $self->name;
        my $code = $self->transformer_code;
        return eval "#line 1 \"$name\"\nsub { (local \$_, my \$roles) = \@_; $code }" || confess $@;
    },
);

my $ANON_SERIAL = 0;

sub init_meta {
    my ($class, %args) = @_;
    my $name = delete $args{for_class};
    $name = sprintf "MR::Rest::Result::__ANON__::%s", ++$ANON_SERIAL unless defined $name;
    Mouse->init_meta(for_class => $name);
    Mouse::Util::MetaRole::apply_metaroles(
        for => $name,
        class_metaroles => {
            class => ['MR::Rest::Meta::Class::Trait::Result'],
        },
    );
    my $rolename = "${name}::Role";
    my $rolemeta = MR::Rest::Meta::Role::Trait::Result->init_meta(%args, for_class => $rolename);
    Mouse::Util::apply_all_roles($name, $rolename);
    my $meta = $name->meta;
    $meta->add_method(role => sub { $rolename });
    $meta->field_traits($args{field_traits}) if $args{field_traits};
    return $meta;
}

before make_immutable => sub {
    my ($self) = @_;
    $self->transformer_code;
    $self->transformer;
    return;
};

no Mouse::Role;

1;
