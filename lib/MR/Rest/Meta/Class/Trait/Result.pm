package MR::Rest::Meta::Class::Trait::Result;

use Mouse::Role;

use MR::Rest::Type;
use MR::Rest::Meta::Role::Result;

with 'MR::Rest::Meta::Role::Trait::Result';
with 'MR::Rest::Role::Doc';

has transformer_code => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        my @code;
        my $class = $self->name;
        my @cond = ('if ($blessed)', 'elsif (defined $_->{_})', 'else');
        foreach my $case (qw/ object composite hash /) {
            my $cond = shift @cond;
            push @code, "$cond {";
            foreach my $field ($self->get_all_fields()) {
                my $name = $field->name;
                push @code, "\n#line " . __LINE__ . " \"" . __FILE__ . " in $class($name)\"\n";
                my $rkey = join '', map "{$_}", split /\./, $name;
                my $result = "\$result$rkey";
                my $accessor = $field->accessor;
                my $value = $case eq 'object' ? "\$_->$accessor"
                    : $case eq 'composite' ? "(exists \$_->$rkey ? \$_->$rkey : \$_->{_}->$accessor)"
                    : "\$_->$rkey";
                my $allow = @{$field->allow} == 0 ? 0
                    : grep({ $_ eq 'all' } @{$field->allow}) ? 1
                    : join(' || ', map "\$roles->$_", @{$field->allow});
                push @code, "if ($allow) {";
                my $type = $field->type_constraint;
                my $exists = 1;
                if (!$field->is_required) {
                    if ($case ne 'object') {
                        $exists = "exists \$_->$rkey";
                    } elsif (!$type->is_a_type_of('Maybe')) {
                        push @code, "my \$v = $value;";
                        $exists = 'defined $v';
                        $value = '$v';
                    }
                }
                push @code, "if ($exists) {";
                if ($type->is_a_type_of('Num')) {
                    push @code, "$result = 0 + $value;";
                } elsif ($type->is_a_type_of('Str')) {
                    my $strval = $case eq 'hash' ? "\"$value\"" : "'' . $value";
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
                    my $param = $type->type_parameter;
                    if ($param->is_a_type_of('Num')) {
                        push @code, "$result = [ map { 0 + \$_ } \@{$value} ];";
                    } elsif ($param->is_a_type_of('Str')) {
                        push @code, "$result = [ map \"\$_\", \@{$value} ];";
                    } elsif ($param->is_a_type_of('Bool')) {
                        push @code, "$result = [ map { \$_ ? \\1 : \\0 } \@{$value} ];";
                    } else {
                        my $code = $param->name->meta->transformer_code;
                        push @code, "\@{$result} = map { $code } \@{$value};";
                    }
                } elsif ($type->is_a_type_of('HashRef')) {
                    my $code = $type->type_parameter->name->meta->transformer_code;
                    if (my $hashby = $field->hashby) {
                        push @code, "\%{$result} = map { \$_->{$hashby} => \$_ } map { $code } \@{$value};"
                    } else {
                        push @code, "my \$h = $value; \%{$result} = map { \$_ => do { local \$_ = \$h->{\$_}; $code } } keys \%\$h;";
                    }
                } elsif ($type->is_a_type_of('Object')) {
                    my $name = $type->name;
                    push @code, "$result = $name\::transform($value, \$roles);";
                } elsif ($type->is_a_type_of('Ref')) {
                    push @code, "$result = $value";
                }
                push @code, '}';
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
        my $code = $self->transformer_code;
        my $line = sprintf '#line %s "%s in %s"', __LINE__, __FILE__, $self->name;
        return eval "$line\nsub { (local \$_, my \$roles) = \@_; $code }" || confess $@;
    },
);

has has_access_restrictions => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'Bool',
    lazy     => 1,
    default  => sub {
        my ($self) = @_;
        foreach my $field ($self->get_all_fields()) {
            return 1 if grep { $_ ne 'all' } @{$field->allow};
            my $type = $field->type_constraint;
            my $param = $type->type_parameter;
            $type = $param if $param && $param->is_a_type_of('ArrayRef');
            if ($type->is_a_type_of('Object')) {
                return 1 if $type->name->meta->has_access_restrictions();
            } elsif ($type->is_a_type_of('HashRef')) {
                return 1 if $type->type_parameter->name->meta->has_access_restrictions();
            }
        }
        return 0;
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
