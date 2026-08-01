#!/usr/bin/env perl

## Regression test for timestampFormat handling on the SEND side, driven
## through the real Shape::finalize path (structure -> members). NO AWS.
##
## Timestamps in requests are always structure members, so the formatting
## decision lives in finalize_structure, where both the member's `location`
## and the raw epoch are in hand. Format resolution, most-specific first:
##   member timestampFormat -> shape timestampFormat -> location default
##   (header=>rfc822, querystring=>iso8601) -> protocol body default
##   (json/rest-json=>unixTimestamp, else iso8601).
##
## Input contract (deliberately narrower than boto: format, don't date-parse):
##   epoch seconds, or any object that can ->epoch (Time::Piece, DateTime,
##   duck-typed - never loaded here). Bare strings croak.

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);
use Time::Piece;

use_ok('Amazon::API::Botocore::Shape');
use_ok('Amazon::API::Botocore::Shape::Utils');

my $EPOCH = 1_434_579_118;               # Wed, 17 Jun 2015 22:11:58 GMT
my $ISO   = '2015-06-17T22:11:58Z';
my $RFC   = 'Wed, 17 Jun 2015 22:11:58 GMT';

Amazon::API::Botocore::Shape::Utils::register_service_shapes(
  'tstest',
  { TS     => { type => 'timestamp' },                                  # unformatted
    TSiso  => { type => 'timestamp', timestampFormat => 'iso8601' },
    TSunix => { type => 'timestamp', timestampFormat => 'unixTimestamp' },
    Req    => {
      type    => 'structure',
      members => {
        Explicit  => { shape => 'TSiso' },                                          # explicit iso8601
        ExplicitU => { shape => 'TSunix' },                                         # explicit unixTimestamp
        HdrTime   => { shape => 'TS', location => 'header',      locationName => 'X-Time' },
        QryTime   => { shape => 'TS', location => 'querystring', locationName => 'q' },
        BodyTime  => { shape => 'TS' },                                             # protocol default
      },
    },
  }
);

sub finalize_req {
  my ( $protocol, %values ) = @_;
  my $class = Amazon::API::Botocore::Shape::Utils::require_shape( 'Req', 'tstest' );
  return $class->new( {%values} )->finalize($protocol);
}

## ---- explicit formats win, regardless of protocol ----
my $rx = finalize_req( 'rest-xml',
  Explicit => $EPOCH, ExplicitU => $EPOCH, HdrTime => $EPOCH, QryTime => $EPOCH, BodyTime => $EPOCH );

is( $rx->{Explicit},  $ISO,   'explicit iso8601 member -> ISO string' );
is( $rx->{ExplicitU}, $EPOCH, 'explicit unixTimestamp member -> epoch number' );

## ---- location defaults ----
is( $rx->{HdrTime}, $RFC, 'header member with no format -> rfc822 (location default)' );
is( $rx->{QryTime}, $ISO, 'querystring member with no format -> iso8601 (location default)' );

## ---- protocol body default: rest-xml -> iso8601 ----
is( $rx->{BodyTime}, $ISO, 'unformatted body member under rest-xml -> iso8601' );

## ---- protocol body default: json -> unixTimestamp; location still wins ----
my $js = finalize_req( 'json', HdrTime => $EPOCH, BodyTime => $EPOCH, Explicit => $EPOCH );
is( $js->{BodyTime}, $EPOCH, 'unformatted body member under json -> unixTimestamp' );
is( $js->{HdrTime}, $RFC,    'header member stays rfc822 under json (location beats protocol)' );
is( $js->{Explicit}, $ISO,   'explicit format beats json protocol default' );

## ---- input contract: object with ->epoch (Time::Piece) ----
my $tp = gmtime($EPOCH);
isa_ok( $tp, 'Time::Piece', 'fixture is a Time::Piece' );
my $obj = finalize_req( 'rest-xml', BodyTime => $tp );
is( $obj->{BodyTime}, $ISO, 'Time::Piece input formats via ->epoch (no dep loaded)' );

## a minimal duck-typed object (proves we do not isa DateTime) ----
{
  package My::Clock;
  sub new   { return bless { e => $_[1] }, $_[0] }
  sub epoch { return $_[0]->{e} }
}
my $duck = finalize_req( 'rest-xml', BodyTime => My::Clock->new($EPOCH) );
is( $duck->{BodyTime}, $ISO, 'any ->epoch object works (duck-typed, not isa)' );

## ---- input contract: bare string is refused, not date-parsed ----
my $err = eval { finalize_req( 'json', BodyTime => '2015-06-17' ); 1 };
ok( !$err, 'bare date string croaks instead of being parsed' );
like( $EVAL_ERROR, qr/epoch seconds or a Time::Piece/sm, 'croak names the accepted input types' );

## ---- fractional epoch survives unixTimestamp ----
my $frac = finalize_req( 'json', ExplicitU => '1434579118.5' );
is( $frac->{ExplicitU}, 1434579118.5, 'fractional epoch preserved for unixTimestamp' );

done_testing;
