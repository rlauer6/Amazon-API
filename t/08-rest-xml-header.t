#!/usr/bin/env perl

## Regression test for Amazon::API's location=>'header' awareness on BOTH
## legs of a rest-xml round-trip (the counterpart to 04-rest-xml-payload.t
## and 05-rest-xml-nonpayload.t). NO live AWS call.
##
## Modeled on CloudFront's UpdateDistribution / GetDistributionConfig, whose
## request/response shapes carry members in three locations at once:
##   - DistributionConfig : the payload (XML body root)
##   - IfMatch / ETag      : location => 'header'  (If-Match / ETag headers)
##   - Id                  : location => 'uri'     (path segment)
##
## Guards two symmetric bugs:
##
## SEND: init_botocore_request extracted uri- and querystring-located members
## but was blind to header-located ones. IfMatch was left in the parameter
## hash, so for a payload rest-xml request it serialized into the body as a
## SECOND root element alongside <DistributionConfig> (two roots ->
## generate_xml croaks / AWS MalformedInput), and its value never reached the
## wire as an If-Match header.
##
## RECEIVE: decode_response only ever read the response BODY. A header-located
## output member (ETag) arrives ONLY as an HTTP response header, so it was
## silently dropped -- leaving callers with no ETag to feed the next IfMatch.

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);

use_ok('Amazon::API');
use_ok('Amazon::API::NullLogger');
use_ok('Amazon::API::HTTP::Response');
use_ok('Amazon::API::Botocore::Shape::Utils');

## ----------------------------------------------------------------------
## Minimal UpdateDistribution / GetDistributionConfig-shaped model
## ----------------------------------------------------------------------
my %shapes = (
  String => { type => 'string' },

  DistributionConfig => {
    type     => 'structure',
    required => [qw(CallerReference Enabled)],
    members  => {
      CallerReference => { shape => 'String' },
      Enabled         => { shape => 'String' },
    },
  },

  ## request: payload + header sibling + uri sibling
  UpdateDistributionRequest => {
    type     => 'structure',
    required => [qw(DistributionConfig Id)],
    members  => {
      DistributionConfig => {
        shape        => 'DistributionConfig',
        locationName => 'DistributionConfig',
        xmlNamespace => { uri => 'http://cloudfront.amazonaws.com/doc/2020-05-31/' },
      },
      IfMatch => { shape => 'String', location => 'header', locationName => 'If-Match' },
      Id      => { shape => 'String', location => 'uri',    locationName => 'Id' },
    },
    payload => 'DistributionConfig',
  },

  ## response: payload + header sibling (ETag)
  GetDistributionConfigResult => {
    type    => 'structure',
    members => {
      DistributionConfig => { shape => 'DistributionConfig', locationName => 'DistributionConfig' },
      ETag               => { shape => 'String', location => 'header', locationName => 'ETag' },
    },
    payload => 'DistributionConfig',
  },
);

Amazon::API::Botocore::Shape::Utils::register_service_shapes( 'TestCF', \%shapes );

package Amazon::API::TestCF {
  our @ISA = ('Amazon::API');
}

my $api = bless {
  botocore_metadata   => { protocol => 'rest-xml', },
  botocore_operations => {
    UpdateDistribution => {
      input => { shape => 'UpdateDistributionRequest', payload => 'DistributionConfig', },
      http  => { method => 'PUT', requestUri => '/2020-05-31/distribution/{Id}/config', },
    },
    GetDistributionConfig => {
      output => { shape => 'GetDistributionConfigResult', },
      http   => { method => 'GET', requestUri => '/2020-05-31/distribution/{Id}/config', },
    },
  },
  service         => 'cloudfront',
  botocore_shapes => \%shapes,
  logger          => Amazon::API::NullLogger->new,
  },
  'Amazon::API::TestCF';

## ======================================================================
## SEND leg: init_botocore_request + serialize_content
## ======================================================================
$api->set_action('UpdateDistribution');

my $input_params = {
  Id                 => 'E1N3IU9UZWSMQT',
  IfMatch            => 'E2QWRUHAPOMQZL',
  DistributionConfig => {
    CallerReference => 'test-reference-1234',
    Enabled         => 'false',
  },
};

my $parameters = eval { $api->init_botocore_request($input_params) };

ok( !$EVAL_ERROR, 'init_botocore_request did not die' )
  or diag("error: $EVAL_ERROR");

## the header member is pulled out of the body...
ok( !exists $parameters->{IfMatch}, 'header member (IfMatch) extracted, not left in the body' )
  or diag( explain($parameters) );

## ...the uri member too...
ok( !exists $parameters->{Id}, 'uri member (Id) extracted, not left in the body' );

## ...and stashed for submit() as its wire header name
my $req_headers = $api->get_botocore_request_headers;

is( ref $req_headers, 'HASH', 'request header stash is a hashref' );
is( $req_headers->{'If-Match'}, 'E2QWRUHAPOMQZL', 'IfMatch stashed under its wire name If-Match' );
ok( !exists $req_headers->{ETag}, 'no stray headers stashed' );

## the payload survives and serializes to a SINGLE root
my $content = $api->serialize_content($parameters);

ok( $content, 'serialize_content produced non-empty content' );
like( $content, qr/<DistributionConfig/xsm, 'body root is the payload member' );
like( $content, qr/CallerReference/xsm,      'body carries payload content' );
unlike( $content, qr/<IfMatch/xsm, 'body does NOT contain the header member (no second root)' );
unlike( $content, qr/<Id\b/xsm,    'body does NOT contain the uri member' );

## undef header value: still removed from the body (no phantom second root),
## but NOT emitted as a header
$api->set_action('UpdateDistribution');
my $p2 = $api->init_botocore_request(
  { Id                 => 'E1N3IU9UZWSMQT',
    IfMatch            => undef,
    DistributionConfig => { CallerReference => 'r', Enabled => 'false' },
  }
);

ok( !exists $p2->{IfMatch}, 'undef header member removed from body (no phantom root)' );
ok( !exists $api->get_botocore_request_headers->{'If-Match'}, 'undef header value not emitted as a header' );

## ======================================================================
## RECEIVE leg: decode_response lifts the header output member
## ======================================================================
## The shape serializer's body-shaping is orthogonal to (and covered by)
## other tests; stub it to a representative body hashref so this test
## isolates the header-lift decode_response now performs after serialize.
package StubSerializer {
  sub new          { return bless {}, shift }
  sub set_protocol { return }
  sub set_logger   { return }
  sub serialize    { return { DistributionConfig => { CallerReference => 'foo' } } }
}

$api->set_action('GetDistributionConfig');
$api->set_serializer( StubSerializer->new );

my $http_response = Amazon::API::HTTP::Response->new(
  { content => '<?xml version="1.0"?><DistributionConfig><CallerReference>foo</CallerReference></DistributionConfig>',
    status  => 200,
    reason  => 'OK',
    success => 1,
    headers => {
      'content-type' => 'text/xml',
      'etag'         => 'E2QWRUHAPOMQZL',    # HTTP::Tiny lowercases header keys
    },
  }
);

my $result = eval { $api->decode_response($http_response) };

ok( !$EVAL_ERROR, 'decode_response did not die' )
  or diag("error: $EVAL_ERROR");

is( ref $result, 'HASH', 'decode_response returned a hashref' );
is( $result->{ETag}, 'E2QWRUHAPOMQZL', 'header output member (ETag) lifted from response headers into the result' )
  or diag( explain($result) );
ok( exists $result->{DistributionConfig}, 'body output member preserved alongside the lifted header' );

done_testing;
