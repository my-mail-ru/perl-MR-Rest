package MR::Rest::Header::Parameterized;

# RFC5987, RFC2616

use Mouse;

use Encode ();
use URI::Escape::XS ();
use Scalar::Util ();

use overload
    '""' => sub { $_[0]->encode },
    '0+' => sub { Scalar::Util::refaddr($_[0]) },
    fallback => 1;

has value => (
    is  => 'rw',
    isa => 'Str',
    required => 1,
);

has params => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    if (@_ == 1 && !ref $_[0]) {
        my ($origin) = @_;
        my ($value, $params) = $class->_decode($origin);
        return $class->$orig(value => $value, params => $params, _encode => $origin);
    } else {
        return $class->$orig(@_);
    }
};

sub decode {
    my ($value, $params) = $_[0]->_decode($_[1]);
    return __PACKAGE__->new(value => $value, params => $params);
}

has encode => (
    init_arg => '_encode',
    is  => 'ro',
    isa => 'Str',
    lazy    => 1,
    builder => '_encode',
    clearer => '_clear_encode',
);

sub param {
    if (@_ == 2) {
        return $_[0]->params->{lc $_[1]};
    } else {
        $_[0]->params->{lc $_[1]} = $_[2];
        $_[0]->_clear_encode();
        return;
    }
}

# RFC 2616 2.2
# OCTET          = <any 8-bit sequence of data>
# CHAR           = <any US-ASCII character (octets 0 - 127)>
# UPALPHA        = <any US-ASCII uppercase letter "A".."Z">
# LOALPHA        = <any US-ASCII lowercase letter "a".."z">
# ALPHA          = UPALPHA | LOALPHA
# DIGIT          = <any US-ASCII digit "0".."9">
# CTL            = <any US-ASCII control character (octets 0 - 31) and DEL (127)>
# CR             = <US-ASCII CR, carriage return (13)>
# LF             = <US-ASCII LF, linefeed (10)>
# SP             = <US-ASCII SP, space (32)>
# HT             = <US-ASCII HT, horizontal-tab (9)>
# <">            = <US-ASCII double-quote mark (34)>
# CRLF           = CR LF
# LWS            = [CRLF] 1*( SP | HT )
# TEXT           = <any OCTET except CTLs, but including LWS>
# HEX            = "A" | "B" | "C" | "D" | "E" | "F" | "a" | "b" | "c" | "d" | "e" | "f" | DIGIT
# token          = 1*<any CHAR except CTLs or separators>
# separators     = "(" | ")" | "<" | ">" | "@" | "," | ";" | ":" | "\" | <"> | "/" | "[" | "]" | "?" | "=" | "{" | "}" | SP | HT
# comment        = "(" *( ctext | quoted-pair | comment ) ")"
# ctext          = <any TEXT excluding "(" and ")">
# quoted-string  = ( <"> *(qdtext | quoted-pair ) <"> )
# qdtext         = <any TEXT except <">>
# quoted-pair    = "\" CHAR

# RFC 5987 3.2.1
# value         = token / quoted-string
# quoted-string = <quoted-string, defined in [RFC2616], Section 2.2>
# token         = <token, defined in [RFC2616], Section 2.2>
# parameter     = reg-parameter / ext-parameter
# reg-parameter = parmname LWSP "=" LWSP value
# ext-parameter = parmname "*" LWSP "=" LWSP ext-value
# parmname      = 1*attr-char
# ext-value     = charset  "'" [ language ] "'" value-chars ; like RFC 2231's <extended-initial-value> (see [RFC2231], Section 7)
# charset       = "UTF-8" / "ISO-8859-1" / mime-charset
# mime-charset  = 1*mime-charsetc
# mime-charsetc = ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "+" / "-" / "^" / "_" / "`" / "{" / "}" / "~"
# ; as <mime-charset> in Section 2.3 of [RFC2978] except that the single quote is not included SHOULD be registered in the IANA charset registry
# language      = <Language-Tag, defined in [RFC5646], Section 2.1>
# value-chars   = *( pct-encoded / attr-char )
# pct-encoded   = "%" HEXDIG HEXDIG ; see [RFC3986], Section 2.1
# attr-char     = ALPHA / DIGIT / "!" / "#" / "$" / "&" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" ; token except ( "*" / "'" / "%" )

my $CHAR = qr/[\x00-\x7f]/;
my $TEXT = qr/[\t\x20-\xff]/;
my $QDTEXT = qr/[\t\x20-\x21\x23-\xff]/;
my $TOKEN = qr/[\x21\x23-\x27\x2a\x2b\x2d\x2e\x30-\x39\x41-\x5a\x5e-\x7a\x7c\x7e\x7f]+/;
my $MAIN_VALUE = qr/$TOKEN(?:\/$TOKEN)?/;
my $QUOTED_STRING = qr/"((?:$QDTEXT|\\$CHAR)+)"/;
my $VALUE = qr/(?:($TOKEN)|$QUOTED_STRING)/;
my $ATTR_CHAR = qr/[A-Za-z0-9\!\#\$\&+\-\.\^\_\`\|\~]/;
my $PARMNAME = qr/($ATTR_CHAR+)/;
my $REG_PARAM = qr/$PARMNAME\s*=\s*$VALUE/;
my $PCT_ENCODED = qr/%[0-9A-Fa-f]{2}/;
my $EXT_VALUE = qr/((?i)UTF-8|ISO-8859-1)'(?:[A-Za-z0-9-])?'((?:$ATTR_CHAR|$PCT_ENCODED)*)/;
my $EXT_PARAM = qr/$PARMNAME\*\s*=\s*$EXT_VALUE/;

my $UTF_8 = Encode::find_encoding('UTF-8');
my $ISO_8859_1 = Encode::find_encoding('ISO-8859-1');
my %ENC = ('UTF-8' => $UTF_8, 'ISO-8859-1' => $ISO_8859_1);

sub _decode {
    my ($class, $header) = @_;
    $header =~ s/^\s*($MAIN_VALUE)\s*(?=;|$)//o
        or confess "Invalid header value: $_[1]";
    my $value = lc $1;
    my (%params, %uniq);
    while ($header =~ s/^\s*;\s*(?:$REG_PARAM|$EXT_PARAM)\s*(?=;\s*|$)//o) {
        my $uname;
        if (defined $1) {
            my $name = lc $1;
            $uname = $name;
            my $value = defined $2 ? $2 : do { my $v = $3; $v =~ s/\\(.)/$1/g; Encode::decode($ISO_8859_1, $v) };
            $params{$name} = $value unless exists $params{$name};
        } else {
            my $name = lc $4;
            $uname = "$name*";
            my $value = Encode::decode($ENC{uc $5}, URI::Escape::XS::decodeURIComponent($6));
            $params{$name} = $value;
        }
        die "Invalid header value: $_[1]" if exists $uniq{$uname};
        $uniq{$uname} = 1;
    }
    confess "Invalid header value: $_[1]" if length $header;
    return ($value, \%params);
}

sub _encode {
    my ($self) = @_;
    my $value = $self->value;
    die "Invalid header value: $value" unless $value =~ /^$MAIN_VALUE$/o;
    my @params;
    my $params = $self->params;
    foreach my $name (keys %$params) {
        die "Invalid header parameter name: $name" unless $name =~ /^$PARMNAME$/o;
        my $value = $params->{$name};
        if ($value =~ /^$TOKEN$/o) {
        } elsif ($value =~ /^$TEXT+$/o) {
            $value = Encode::encode($ISO_8859_1, $value);
            $value =~ s/(["\\])/\\$1/go;
            $value = qq/"$value"/;
        } else {
            $name .= '*';
            $value = "UTF-8''" . URI::Escape::XS::encodeURIComponent(Encode::encode($UTF_8, $value));
        }
        push @params, "$name=$value";
    }
    return join '; ', $value, @params;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
