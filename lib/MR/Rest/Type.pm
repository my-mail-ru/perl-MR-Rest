package MR::Rest::Type;

use Mouse::Util::TypeConstraints;

enum 'MR::Rest::Type::Method' => [qw/ GET POST PUT DELETE HEAD /];

enum 'MR::Rest::Type::ParameterLocation' => [qw/ path query body header form /];

subtype 'MR::Rest::Type::Status'
    => as 'Int'
    => where { $_ == 100 || $_ == 101 || $_ >= 200 && $_ <= 206 || $_ >= 300 && $_ <= 307 || $_ >= 400 && $_ < 417 || $_ >= 500 && $_ <= 505 }
    => message { "Not valid HTTP status code '$_'" };

subtype 'MR::Rest::Type::Error'
    => as 'Maybe[Str]'
    => where { !defined || /^[a-z][a-z0-9_]*$/ }
    => message { "Not valid error identificatior: only [a-z0-9_]+ are allowed" };

subtype 'MR::Rest::Type::ParametersName'
    => as 'ClassName'
    => where { $_->meta->does('MR::Rest::Meta::Class::Trait::Parameters') };

subtype 'MR::Rest::Type::ResultName'
    => as 'ClassName'
    => where { $_->meta->isa('MR::Rest::Meta::Class::Result') };

subtype 'MR::Rest::Type::ResponsesName'
    => as 'ClassName'
    => where { $_->meta->does('MR::Rest::Meta::Class::Trait::Responses') };

subtype 'MR::Rest::Type::Allow'
    => as 'ArrayRef[Str]';
coerce 'MR::Rest::Type::Allow'
    => from 'Str'
    => via { [$_] };

subtype 'MR::Rest::Type::BodyHandle'
    => as 'Object'
    => where { $_->can('getline') && $_->can('close') }
    => message { "Methods getline() and close() are required" };

subtype 'MR::Rest::Type::Headers'
    => as 'HTTP::Headers';
coerce 'MR::Rest::Type::Headers'
    => from 'HashRef'
    => via { HTTP::Headers->new(%$_) };
coerce 'MR::Rest::Type::Headers'
    => from 'ArrayRef'
    => via { HTTP::Headers->new(@$_) };

subtype 'MR::Rest::Type::Version'
    => as 'Str',
    => where { /^\d+(?:\.\d+)*$/ };

subtype 'MR::Rest::Type::Resource::Owner'
    => as 'Maybe[CodeRef]';
coerce 'MR::Rest::Type::Resource::Owner'
    => from 'Str'
    => via { my $p = $_; sub { $_[0]->params->$p } };

subtype 'MR::Rest::Type::Path'
    => as 'Str',
    => where { /^\// };

subtype 'MR::Rest::Type::Config::Allow'
    => as 'Str'
    => where { my $t = find_type_constraint($_); $t && $t->is_a_type_of('ArrayRef') };

no Mouse::Util::TypeConstraints;

1;
