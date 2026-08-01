#!/usr/bin/env perl

## Unit test for Amazon::API::_resolve_request_content -- the per-protocol
## decision that turns the built parameter hash into the request body.
##
## This is the block extracted from init_botocore_request. It is tested in
## ISOLATION (no credentials, no network, no shape building, no URI
## construction): we bless a bare Amazon::API-shaped hashref carrying only
## a botocore_shapes map -- the single accessor the method touches -- and
## call the real method directly against a protocol matrix.
##
## Each row of the matrix is a (shape, protocol, method, params) -> body
## expectation. This exists because serialization regressions have been
## silent: an empty body to a JSON service yields SerializationException,
## and a mis-rooted rest-xml body yields MalformedInput -- both from AWS,
## far from the code that caused them. The matrix pins every branch so the
## next such regression fails here, in milliseconds, instead of on the wire.
##
## Regressions this would have caught:
##   - dropped `else { $content = \%parameters }`  -> plain-json empty body
##   - unwrapping past the shape name (rest-xml)    -> sibling <_attr> / 2 roots
##   - unwrapping a payload body                    -> lost payload root

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);

use_ok('Amazon::API');

## Minimal shape registry: just enough for the payload/non-payload branch.
my %SHAPES = (
  ListCertificatesRequest         => { members => {} },                       # plain json, no payload
  DescribeCertificateRequest      => { members => {} },                       # plain json, no payload
  ChangeResourceRecordSetsRequest => { members => { ChangeBatch => {} } },    # rest-xml, no payload
  PutBucketWebsiteRequest         => { payload => 'WebsiteConfiguration' },   # rest-xml, payload
  CreateInvalidationRequest       => { payload => 'InvalidationBatch' },      # rest-xml, payload
  SomeRestJsonRequest             => { members => {} },                       # rest-json, no payload
);

## Bare object: _resolve_request_content only calls $self->get_botocore_shapes.
my $api = bless { botocore_shapes => \%SHAPES }, 'Amazon::API';

## helper: name => [ shape, protocol, method, params_hashref, expected ]
##   expected: a hashref to compare with is_deeply, or undef.
my @cases = (
  [ 'plain json POST flat params -> flat body (ACM regression)',
    'ListCertificatesRequest', 'json', 'POST',
    { CertificateStatuses => ['ISSUED'] },
    { CertificateStatuses => ['ISSUED'] },
  ],

  [ 'plain json POST empty params -> {} (not undef -> avoids empty-body SerializationException)',
    'ListCertificatesRequest', 'json', 'POST',
    {},
    {},
  ],

  [ 'rest-xml non-payload -> body wrapped under the shape name (single root, xmlns rides it)',
    'ChangeResourceRecordSetsRequest', 'rest-xml', 'POST',
    { ChangeResourceRecordSetsRequest => { ChangeBatch => { Comment => 'x' } } },
    { ChangeResourceRecordSetsRequest => { ChangeBatch => { Comment => 'x' } } },
  ],

  [ 'rest-xml payload -> payload member is the root (unwrapped)',
    'PutBucketWebsiteRequest', 'rest-xml', 'POST',
    { PutBucketWebsiteRequest => { WebsiteConfiguration => { IndexDocument => {} } } },
    { WebsiteConfiguration => { IndexDocument => {} } },
  ],

  [ 'rest-json non-payload -> inner members, NO xml wrapper element',
    'SomeRestJsonRequest', 'rest-json', 'POST',
    { SomeRestJsonRequest => { Foo => 'bar' } },
    { Foo => 'bar' },
  ],

  [ 'non-POST with empty params -> undef (no body)',
    'DescribeCertificateRequest', 'json', 'GET',
    {},
    undef,
  ],

  [ 'rest-xml non-payload with empty inner -> undef',
    'ChangeResourceRecordSetsRequest', 'rest-xml', 'POST',
    { ChangeResourceRecordSetsRequest => {} },
    undef,
  ],

  [ 'query protocol -> flat params (serialize_content url-encodes downstream)',
    'ListCertificatesRequest', 'query', 'POST',
    { Action => 'Foo' },
    { Action => 'Foo' },
  ],
);

for my $case (@cases) {
  my ( $name, $shape, $protocol, $method, $params, $expected ) = @{$case};

  my $got = $api->_resolve_request_content( $shape, $protocol, $method, $params );

  if ( defined $expected ) {
    is_deeply( $got, $expected, $name )
      or diag( "got: " . ( defined $got ? explain($got) : 'undef' ) );
  }
  else {
    is( $got, undef, $name );
  }
}

## Extra guard on the headline regression: the plain-json body must be a
## non-empty structure so downstream encode_json produces real JSON, not ''.
my $acm = $api->_resolve_request_content(
  'ListCertificatesRequest', 'json', 'POST',
  { CertificateStatuses => ['ISSUED'] },
);
ok( $acm && ref $acm eq 'HASH' && keys %{$acm},
  'plain-json body is a populated hashref (encodes to real JSON, not empty body)' );

done_testing;
