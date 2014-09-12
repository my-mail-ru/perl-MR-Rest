package MR::Rest::Type;

use Mouse::Util::TypeConstraints;

enum 'MR::Rest::Type::Method' => [qw/ GET POST PUT DELETE HEAD /];

my @allow = qw/ SELF FRIENDS FRIENDS_FRIENDS FOLLOWERS ALL /;
my %allow = map { $_ => 1 } @allow;
subtype 'MR::Rest::Type::Allow'
    => as 'ArrayRef'
    => where { @$_ == grep $allow{$_}, @$_ }
    => message { "Possible elements of array are @allow" };

enum 'MR::Rest::Type::ParameterLocation' => [qw/ PATH QUERY_STRING BODY /];

subtype 'MR::Rest::Type::Status'
    => as 'Int'
    => where { $_ == 100 || $_ == 101 || $_ >= 200 && $_ <= 206 || $_ >= 300 && $_ <= 307 || $_ >= 400 && $_ < 417 || $_ >= 500 && $_ <= 505 }
    => message { "Not valid HTTP status code" };

subtype 'MR::Rest::Type::Error'
    => as 'Maybe[Str]'
    => where { !defined || /^[a-z][a-z0-9_]*$/ }
    => message { "Not valid error identificatior: only [a-z0-9_]+ are allowed" };

no Mouse::Util::TypeConstraints;

1;
