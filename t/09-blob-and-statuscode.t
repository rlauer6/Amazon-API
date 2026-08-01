#!/usr/bin/env perl

## Regression tests for two "registry-readable" botocore traits the
## serializer was ignoring, both driven against the real code paths:
##
##   location: statusCode  - an output member fed from the HTTP status line
##                           (rest-json), never present in the body. Lifted
##                           in decode_response alongside header members.
##
##   type: blob            - value blobs (KMS Plaintext, Kinesis Data) are
##                           base64 on the wire and must be encoded on send /
##                           decoded on receive; STREAMING blobs (an S3
##                           PutObject body) are the raw payload and must pass
##                           through untouched. Handled at the finalize (send)
##                           and Shape::Serializer (receive) scalar seams,
##                           gated on the shape's `streaming` flag.

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);
use MIME::Base64 qw(encode_base64 decode_base64);

use_ok('Amazon::API');
use_ok('Amazon::API::NullLogger');
use_ok('Amazon::API::HTTP::Response');
use_ok('Amazon::API::Botocore::Shape');
use_ok('Amazon::API::Botocore::Shape::Serializer');
use_ok('Amazon::API::Botocore::Shape::Utils');

## ======================================================================
## location: statusCode  (receive, via real decode_response)
## ======================================================================
package Amazon::API::TestSC { our @ISA = ('Amazon::API'); }

## stub serializer: body shaping is orthogonal + covered elsewhere; this
## isolates decode_response's status/header lift.
package StubSerializer {
  sub new          { return bless {}, shift }
  sub set_protocol { return }
  sub set_logger   { return }
  sub serialize    { return { Reason => 'ok' } }    # a body member
}

my $sc = bless {
  botocore_metadata   => { protocol => 'rest-json' },
  botocore_operations => {
    PublishBatch => {
      output => { shape => 'PublishBatchResult' },
      http   => { method => 'POST', requestUri => '/batch' },
    },
  },
  botocore_shapes => {
    PublishBatchResult => {
      type    => 'structure',
      members => {
        Reason     => { shape => 'String' },
        StatusCode => { shape => 'Integer', location => 'statusCode' },
      },
    },
  },
  service    => 'sns',
  serializer => StubSerializer->new,
  logger     => Amazon::API::NullLogger->new,
  },
  'Amazon::API::TestSC';

$sc->set_action('PublishBatch');

my $sc_rsp = Amazon::API::HTTP::Response->new(
  { content => '{"Reason":"ok"}', status => 204, reason => 'No Content', success => 1,
    headers => { 'content-type' => 'application/json' } } );

my $sc_result = eval { $sc->decode_response($sc_rsp) };
ok( !$EVAL_ERROR, 'decode_response (statusCode) did not die' ) or diag($EVAL_ERROR);
is( $sc_result->{StatusCode}, 204, 'statusCode output member filled from the HTTP status line' );
ok( exists $sc_result->{Reason}, 'body member preserved alongside the lifted statusCode' );

## ======================================================================
## type: blob  (send, via real Shape::finalize)
## ======================================================================
my $plain = 'binary\0payload bytes';

my $value_blob = Amazon::API::Botocore::Shape->new(
  { type => 'blob', _value => $plain, service => 'test' } );
is( $value_blob->finalize('json'), encode_base64( $plain, q{} ),
  'value blob is base64-encoded on send (single line)' );

my $stream_blob = Amazon::API::Botocore::Shape->new(
  { type => 'blob', streaming => 1, _value => $plain, service => 'test' } );
is( $stream_blob->finalize('json'), $plain,
  'streaming blob passes through raw on send (NOT base64)' );

my $undef_blob = Amazon::API::Botocore::Shape->new(
  { type => 'blob', _value => undef, service => 'test' } );
is( $undef_blob->finalize('json'), undef, 'undef blob stays undef (no encode)' );

## same encode works regardless of protocol (blobs are base64 on all wires)
for my $proto (qw(json rest-json rest-xml query ec2)) {
  my $b = Amazon::API::Botocore::Shape->new( { type => 'blob', _value => $plain, service => 'test' } );
  is( $b->finalize($proto), encode_base64( $plain, q{} ), "value blob base64 under $proto" );
}

## ======================================================================
## type: blob  (receive, via real Shape::Serializer)
## ======================================================================
Amazon::API::Botocore::Shape::Utils::register_service_shapes(
  'testblob',
  { ValueBlob  => { type => 'blob' },
    StreamBlob => { type => 'blob', streaming => 1 },
  }
);

my $ser = Amazon::API::Botocore::Shape::Serializer->new(
  { service => 'testblob', protocol => 'json', logger => Amazon::API::NullLogger->new } );

my $wire = encode_base64( $plain, q{} );

is( $ser->serialize( service => 'testblob', shape => 'ValueBlob', data => $wire ),
  $plain, 'value blob is base64-decoded on receive' );

is( $ser->serialize( service => 'testblob', shape => 'StreamBlob', data => $plain ),
  $plain, 'streaming blob passes through raw on receive (NOT decoded)' );

done_testing;
