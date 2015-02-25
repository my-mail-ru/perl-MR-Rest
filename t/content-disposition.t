# Test data was taken from http://greenbytes.de/tech/tc2231/

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use lib 'lib';
use MR::Rest::Header::Parameterized;

my @tests = (
    # Content-Disposition: Disposition-Type Inline
    [ 'Content-Disposition: inline', 'inline' ],
    [ 'Content-Disposition: "inline"', undef ],
    [ 'Content-Disposition: inline; filename="foo.html"', 'inline', filename => 'foo.html' ],
    [ 'Content-Disposition: inline; filename="Not an attachment!"', 'inline', filename => 'Not an attachment!' ],
    [ 'Content-Disposition: inline; filename="foo.pdf"', 'inline', filename => 'foo.pdf' ],
    # Content-Disposition: Disposition-Type Attachment
    [ 'Content-Disposition: attachment', 'attachment' ],
    [ 'Content-Disposition: "attachment"', undef ],
    [ 'Content-Disposition: ATTACHMENT', 'attachment' ],
    [ 'Content-Disposition: attachment; filename="foo.html"', 'attachment', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; filename="0000000000111111111122222"', 'attachment', filename => '0000000000111111111122222' ],
    [ 'Content-Disposition: attachment; filename="00000000001111111111222222222233333"', 'attachment', filename => '00000000001111111111222222222233333' ],
    [ 'Content-Disposition: attachment; filename="f\oo.html"', 'attachment', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; filename="\"quoting\" tested.html"', 'attachment', filename => '"quoting" tested.html' ],
    [ q/Content-Disposition: attachment; filename="Here's a semicolon;.html"/, 'attachment', filename => q/Here's a semicolon;.html/ ],
    [ 'Content-Disposition: attachment; foo="bar"; filename="foo.html"', 'attachment', foo => 'bar', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; foo="\"\\\\";filename="foo.html"', 'attachment', foo => '"\\', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; FILENAME="foo.html"', 'attachment', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; filename=foo.html', 'attachment', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; filename=foo,bar.html', undef ],
    [ 'Content-Disposition: attachment; filename=foo.html ;', undef ],
    [ 'Content-Disposition: attachment; ;filename=foo', undef ],
    [ 'Content-Disposition: attachment; filename=foo bar.html', undef ],
    [ q/Content-Disposition: attachment; filename='foo.bar'/, 'attachment', filename => q/'foo.bar'/ ],
    [ qq/Content-Disposition: attachment; filename="foo-\xe4.html"/, 'attachment', filename => 'foo-ä.html' ],
    [ qq/Content-Disposition: attachment; filename="foo-\xc3\xa4.html"/, 'attachment', filename => 'foo-Ã¤.html' ],
    [ 'Content-Disposition: attachment; filename="foo-%41.html"', 'attachment', filename => 'foo-%41.html' ],
    [ 'Content-Disposition: attachment; filename="50%.html"', 'attachment', filename => '50%.html' ],
    [ 'Content-Disposition: attachment; filename="foo-%\41.html"', 'attachment', filename => 'foo-%41.html' ],
    [ 'Content-Disposition: attachment; name="foo-%41.html"', 'attachment', name => 'foo-%41.html' ],
    [ qq/Content-Disposition: attachment; filename="\xe4-%41.html"/, 'attachment', filename => 'ä-%41.html' ],
    [ 'Content-Disposition: attachment; filename="foo-%c3%a4-%e2%82%ac.html"', 'attachment', filename => 'foo-%c3%a4-%e2%82%ac.html' ],
    [ 'Content-Disposition: attachment; filename ="foo.html"', 'attachment', filename => 'foo.html' ],
    [ 'Content-Disposition: attachment; filename="foo.html"; filename="bar.html"', undef ],
    [ 'Content-Disposition: attachment; filename=foo[1](2).html', undef ],
    [ 'Content-Disposition: attachment; filename=foo-ä.html', undef ],
    [ 'Content-Disposition: attachment; filename=foo-Ã¤.html', undef ],
    [ 'Content-Disposition: filename=foo.html', undef ],
    [ 'Content-Disposition: x=y; filename=foo.html', undef ],
    [ 'Content-Disposition: "foo; filename=bar;baz"; filename=qux', undef ],
    [ 'Content-Disposition: filename=foo.html, filename=bar.html', undef ],
    [ 'Content-Disposition: ; filename=foo.html', undef ],
    [ 'Content-Disposition: : inline; attachment; filename=foo.html', undef ],
    [ 'Content-Disposition: inline; attachment; filename=foo.html', undef ],
    [ 'Content-Disposition: attachment; inline; filename=foo.html', undef ],
    [ 'Content-Disposition: attachment; filename="foo.html".txt', undef ],
    [ 'Content-Disposition: attachment; filename="bar', undef ],
    [ 'Content-Disposition: attachment; filename=foo"bar;baz"qux', undef ],
    [ 'Content-Disposition: attachment; filename=foo.html, attachment; filename=bar.html', undef ],
    [ 'Content-Disposition: attachment; foo=foo filename=bar', undef ],
    [ 'Content-Disposition: attachment; filename=bar foo=foo ', undef ],
    [ 'Content-Disposition: attachment filename=bar', undef ],
    [ 'Content-Disposition: filename=foo.html; attachment', undef ],
    [ 'Content-Disposition: attachment; xfilename=foo.html', 'attachment', xfilename => 'foo.html' ],
    [ 'Content-Disposition: attachment; filename="/foo.html"', 'attachment', filename => '/foo.html' ],
    [ 'Content-Disposition: attachment; filename="\\\\foo.html"', 'attachment', filename => '\foo.html' ],
    # Content-Disposition: Additional Parameters (optional)
    [ 'Content-Disposition: attachment; creation-date="Wed, 12 Feb 1997 16:29:51 -0500"', 'attachment', 'creation-date' => 'Wed, 12 Feb 1997 16:29:51 -0500' ],
    [ 'Content-Disposition: attachment; modification-date="Wed, 12 Feb 1997 16:29:51 -0500"', 'attachment', 'modification-date' => 'Wed, 12 Feb 1997 16:29:51 -0500' ],
    #[ 'Content-Disposition: foobar', 'attachment' ],
    [ 'Content-Disposition: attachment; example="filename=example.txt"', 'attachment', example => 'filename=example.txt' ],
    [ q/Content-Disposition: attachment; filename*=iso-8859-1''foo-%E4.html/, 'attachment', filename => 'foo-ä.html' ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''foo-%c3%a4-%e2%82%ac.html/, 'attachment', filename => 'foo-ä-€.html' ],
    [ q/Content-Disposition: attachment; filename*=''foo-%c3%a4-%e2%82%ac.html/, undef ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''foo-a%cc%88.html/, 'attachment', filename => 'foo-ä.html' ],
    #[ q/Content-Disposition: attachment; filename*=iso-8859-1''foo-%c3%a4-%e2%82%ac.html/, undef ],
    [ q/Content-Disposition: attachment; filename*=utf-8''foo-%E4.html/, 'attachment', filename => "foo-\x{fffd}.html" ], # modified test
    [ q/Content-Disposition: attachment; filename *=UTF-8''foo-%c3%a4.html/, undef ],
    [ q/Content-Disposition: attachment; filename*= UTF-8''foo-%c3%a4.html/, 'attachment', filename => 'foo-ä.html' ],
    [ q/Content-Disposition: attachment; filename* =UTF-8''foo-%c3%a4.html/, 'attachment', filename => 'foo-ä.html' ],
    [ q/Content-Disposition: attachment; filename*="UTF-8''foo-%c3%a4.html"/, undef ], # test modified accoriding to RFC 5987
    [ 'Content-Disposition: attachment; filename*="foo%20bar.html"', undef ], # test modified accoriding to RFC 5987
    [ q/Content-Disposition: attachment; filename*=UTF-8'foo-%c3%a4.html/, undef ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''foo%/, undef ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''f%oo.html/, undef ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''A-%2541.html/, 'attachment', filename => 'A-%41.html' ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''%5cfoo.html/, 'attachment', filename => '\foo.html' ],
    # RFC2231 Encoding: Continuations (optional)
    # ... unsupported yet, so test are skipped ...
    # RFC2231 Encoding: Fallback Behaviour
    [ q/Content-Disposition: attachment; filename="foo-ae.html"; filename*=UTF-8''foo-%c3%a4.html/, 'attachment', filename => 'foo-ä.html' ],
    [ q/Content-Disposition: attachment; filename*=UTF-8''foo-%c3%a4.html; filename="foo-ae.html"/, 'attachment', filename => 'foo-ä.html' ],
    #[ q/Content-Disposition: attachment; filename*0*=ISO-8859-15''euro-sign%3d%a4; filename*=ISO-8859-1''currency-sign%3d%a4/, 'attachment', 'filename*0*' => q/ISO-8859-15''euro-sign%3d%a4/, 'filename*' => 'currency-sign=¤' ],
    [ q/Content-Disposition: attachment; foobar=x; filename="foo.html"/, 'attachment', foobar => 'x', filename => 'foo.html' ],
    # RFC2047 Encoding
    [ q/Content-Disposition: attachment; filename==?ISO-8859-1?Q?foo-=E4.html?=/, undef ],
    [ q/Content-Disposition: attachment; filename="=?ISO-8859-1?Q?foo-=E4.html?="/, 'attachment', filename => '=?ISO-8859-1?Q?foo-=E4.html?=' ],
);

plan tests => scalar @tests;

foreach my $test (@tests) {
    my ($header, $type, %params) = @$test;
    $header =~ s/^Content-Disposition: //;
    my $h = eval { MR::Rest::Header::Parameterized->new($header) };
    if (defined $type) {
        utf8::decode($_) foreach values %params;
        is_deeply($h ? [$h->value, $h->params] : [], [$type, \%params], $header);
    } else {
        ok(!defined $h, $header)
            or diag(Dumper($h));
    }
}
