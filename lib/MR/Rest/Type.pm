package MR::Rest::Type;

use Mouse::Util::TypeConstraints;

enum 'MR::Rest::Type::Method' => [qw/ GET POST PUT DELETE HEAD /];

enum 'MR::Rest::Type::ParameterLocation' => [qw/ path query body header form /];

subtype 'MR::Rest::Type::Status'
    => as 'Int'
    => where { $_ == 100 || $_ == 101 || $_ >= 200 && $_ <= 206 || $_ >= 300 && $_ <= 307 || $_ >= 400 && $_ < 417 || $_ == 426 || $_ > 427 && $_ < 430 || $_ == 431 || $_ == 444 || $_ == 450 || $_ == 499 || $_ >= 500 && $_ <= 505 }
    => message { "Not valid HTTP status code '$_'" };

subtype 'MR::Rest::Type::Error'
    => as 'Maybe[Str]'
    => where { !defined || /^[a-z][a-z0-9_]*$/ }
    => message { "Not valid error identificatior: only [a-z0-9_]+ are allowed" };

subtype 'MR::Rest::Type::ControllersName'
    => as 'ClassName'
    => where { $_->meta->does('MR::Rest::Meta::Class::Trait::Controllers') };

subtype 'MR::Rest::Type::ParametersName'
    => as 'ClassName'
    => where { $_->meta->does('MR::Rest::Meta::Class::Trait::Parameters') };

subtype 'MR::Rest::Type::ResultName'
    => as 'ClassName'
    => where { $_->meta->does('MR::Rest::Meta::Class::Trait::Result') };

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

no Mouse::Util::TypeConstraints;

1;
