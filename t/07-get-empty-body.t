#!/usr/bin/env perl

## Unit test for Amazon::API::serialize_content -- specifically the JSON
## empty-body handling across HTTP methods. Tested in ISOLATION (no
## credentials, no network, no shape building): we bless a bare
## Amazon::API-shaped hashref carrying only the accessors the method
## reads, and call the real method directly.
##
## Regression this pins (InvalidSignatureException on GetFunction):
##
##   A JSON service with no body is floored to '{}' so an empty POST body
##   is still valid JSON (avoids SerializationException). But a GET has no
##   body -- and _set_request_content appends any defined GET content to
##   the URI as a '?<content>' query string. So a floored '{}' on a
##   bodyless GET became a spurious '?{}' on the URL, which SigV4 then
##   signed over -> "signature we calculated does not match".
##
##   The fix: a bodyless GET serializes to undef (no body, nothing to
##   append), while POST/PUT still floor to '{}'. This matrix pins both
##   so a future change to the floor can't silently reintroduce the '?{}'.

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);

use_ok('Amazon::API');
use_ok('Amazon::API::NullLogger');

## Bare object: serialize_content reads content_type, action, version,
## service, botocore_metadata, http_method, and logger. Nothing else.
sub api {
  my ($method) = @_;
  return bless {
    content_type      => 'application/json',
    action            => q{},
    version           => q{},
    service           => 'lambda',
    botocore_metadata => { protocol => 'rest-json' },
    http_method       => $method,
    logger            => Amazon::API::NullLogger->new,
  }, 'Amazon::API';
}

## name => [ method, params, expected_content ]
my @cases = (
  [ 'bodyless GET serializes to undef (no spurious ?{} query string)',
    'GET', undef, undef,
  ],
  [ 'bodyless GET with empty hashref also -> undef',
    'GET', {}, undef,
  ],
  [ 'bodyless POST still floors to {} (empty-body SerializationException fix intact)',
    'POST', undef, '{}',
  ],
  [ 'POST with a real body serializes it',
    'POST', { FunctionName => 'foo' }, '{"FunctionName":"foo"}',
  ],
  [ 'PUT with empty body floors to {} (body-bearing method)',
    'PUT', {}, '{}',
  ],
);

for my $case (@cases) {
  my ( $name, $method, $params, $expected ) = @{$case};

  my $got = api($method)->serialize_content($params);

  if ( defined $expected ) {
    is( $got, $expected, $name );
  }
  else {
    is( $got, undef, $name );
  }
}

## explicit regression assertion: the exact GetFunction shape -- a GET
## whose only parameter was extracted into the URI, leaving no body.
{
  my $got = api('GET')->serialize_content(undef);
  ok( !defined $got,
    'GetFunction case: bodyless GET yields no content, so no ?{} is appended and the signature stays valid' );
}

done_testing;
