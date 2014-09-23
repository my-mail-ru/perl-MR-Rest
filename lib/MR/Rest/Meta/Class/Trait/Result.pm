package MR::Rest::Meta::Class::Trait::Result;

use Mouse::Role;

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
                        push @code, "$result = do { my \$v = $value; defined \$v ? 0 + \$v : undef };";
                    } elsif ($param->is_a_type_of('Str')) {
                        push @code, "$result = do { my \$v = $value; defined \$v ? \"\$v\" : undef };";
                    } elsif ($param->is_a_type_of('Bool')) {
                        push @code, "$result = do { my \$v = $value; defined \$v ? \$v ? \\1 : \\0 : undef };";
                    }
                } elsif ($type->is_a_type_of('ArrayRef')) {
                    my $code = $type->type_parameter->name->meta->transformer_code;
                    push @code, "\@{$result} = map { $code } \@{$value};";
                } elsif ($type->is_a_type_of('HashRef')) {
                    my $code = $type->type_parameter->name->meta->transformer_code;
                    if (my $hashby = $field->hashby) {
                        push @code, "\%{$result} = map { \$_->{$hashby} => \$_ } map { $code } \@{$value};"
                    } else {
                        push @code, "{ my \$h = $value; \%{$result} = map { \$_ => do { local \$_ = \$h->{\$_}; $code } } keys \%\$h; }";
                    }
                }
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
        my $code = $self->transformer_code;
        return eval "sub { local (\$_) = \@_; $code }" || confess $@;
    },
);

before make_immutable => sub {
    my ($self) = @_;
    $self->transformer_code;
    $self->transformer;
    return;
};

no Mouse::Role;

1;
