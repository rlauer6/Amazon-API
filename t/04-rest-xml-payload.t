#!/usr/bin/env perl

## Regression test for Amazon::API::init_botocore_request's REST-XML
## payload/body resolution.
##
## Drives the real init_botocore_request() against a minimal
## hand-authored botocore model shaped like CloudFront's
## CreateInvalidation (a rest-xml operation with one uri-located member
## and one payload-located member), with NO live AWS call.
##
## Guards against a bug where %parameters was reassigned to the
## unwrapped payload contents and then immediately re-looked-up by the
## now-gone $request_shape_name key, silently producing an empty
## request body (and thus an empty wire content) for every REST-XML/
## JSON operation with a declared payload member.

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);

use_ok('Amazon::API');
use_ok('Amazon::API::NullLogger');
use_ok('Amazon::API::Botocore::Shape');
use_ok('Amazon::API::Botocore::Shape::Utils');

## Minimal CreateInvalidation-shaped model:
##   - DistributionId: uri-located, top-level member
##   - InvalidationBatch: payload-located, the actual XML body root
##   - Paths: nested structure with Quantity + Items (list of strings)
my %shapes = (
  String => { type => 'string' },

  PathList => {
    type   => 'list',
    member => { shape => 'String', locationName => 'Path' },
  },

  Paths => {
    type     => 'structure',
    required => [qw(Quantity Items)],
    members  => {
      Quantity => { shape => 'String' },
      Items    => { shape => 'PathList' },
    },
  },

  InvalidationBatch => {
    type     => 'structure',
    required => [qw(Paths CallerReference)],
    members  => {
      Paths           => { shape => 'Paths' },
      CallerReference => { shape => 'String' },
    },
  },

  CreateInvalidationRequest => {
    type     => 'structure',
    required => [qw(DistributionId InvalidationBatch)],
    members  => {
      DistributionId    => { shape => 'String', location => 'uri', locationName => 'DistributionId' },
      InvalidationBatch => {
        shape        => 'InvalidationBatch',
        locationName => 'InvalidationBatch',
        xmlNamespace => { uri => 'http://cloudfront.amazonaws.com/doc/2020-05-31/' },
      },
    },
    payload => 'InvalidationBatch',
  },
);

Amazon::API::Botocore::Shape::Utils::register_service_shapes( 'TestCF', \%shapes );

## Minimal fixture: a bare blessed Amazon::API-shaped hashref with just
## the accessors init_botocore_request needs, bypassing new() (which
## pulls in credentials/region/network setup unrelated to this test).
{

  package Amazon::API::TestCF;
  our @ISA = ('Amazon::API');
}

my $api = bless {
  botocore_metadata   => { protocol => 'rest-xml', },
  botocore_operations => {
    CreateInvalidation => {
      input => {
        shape   => 'CreateInvalidationRequest',
        payload => 'InvalidationBatch',
      },
      http => {
        method     => 'POST',
        requestUri => '/2020-05-31/distribution/{DistributionId}/invalidation',
      },
    },
  },
  service         => 'cloudfront',
  botocore_shapes => \%shapes,
  logger          => Amazon::API::NullLogger->new,
  },
  'Amazon::API::TestCF';

$api->set_action('CreateInvalidation');

my $input_params = {
  DistributionId    => 'E22W2XA4ZD492W',
  InvalidationBatch => {
    Paths => {
      Quantity => 1,
      Items    => ['/orepan2-s3/modules/02packages.details.txt.gz'],
    },
    CallerReference => 'test-reference-1234',
  },
};

my $parameters = eval { $api->init_botocore_request($input_params) };

ok( !$EVAL_ERROR, 'init_botocore_request did not die' )
  or diag("error: $EVAL_ERROR");

ok( $parameters && ref $parameters eq 'HASH', 'returned a hashref' );

ok( exists $parameters->{InvalidationBatch}, 'parameters contain the payload member (InvalidationBatch)' )
  or diag( explain($parameters) );

ok( !exists $parameters->{DistributionId}, 'uri-located member (DistributionId) was extracted, not left in the body' );

is( $parameters->{InvalidationBatch}{CallerReference},
  'test-reference-1234', 'CallerReference survived into the payload content' );

is( $parameters->{InvalidationBatch}{Paths}{Quantity}, 1, 'Paths.Quantity survived into the payload content' );

## the actual fix under test: serialize_content/generate_xml must
## receive a non-empty structure to produce a non-empty XML body
my $content = $api->serialize_content($parameters);

ok( $content, 'serialize_content produced non-empty content' )
  or diag('content was empty/undef - the empty-body regression');

like( $content, qr/InvalidationBatch/, 'serialized XML contains the InvalidationBatch root element' );
like( $content, qr/CallerReference/,   'serialized XML contains CallerReference' );
like( $content, qr/Quantity/,          'serialized XML contains Quantity' );
unlike( $content, qr/DistributionId/, 'serialized XML body does not contain the uri-located DistributionId' );

done_testing;
