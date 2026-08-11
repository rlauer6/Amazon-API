#!/usr/bin/env perl

## Regression test for Amazon::API's REST-XML request serialization of a
## NON-payload operation (the counterpart to 04-rest-xml-payload.t).
##
## Drives the real init_botocore_request() + serialize_content() against a
## minimal hand-authored botocore model shaped like Route53's
## ChangeResourceRecordSets: a rest-xml operation with one uri-located
## member (HostedZoneId) and one body member (ChangeBatch), and NO declared
## payload member. NO live AWS call.
##
## Guards against the bug where, for a payload-less rest-xml request, the
## shape-name wrapper was unwrapped away and the xmlNamespace (attached as
## _attr on that wrapper) was emitted as a sibling <_attr> element -- so the
## body had TWO top-level roots (<ChangeBatch/> plus <_attr/>) and no
## operation-wrapper root, producing MalformedInput ("Could not parse XML")
## from AWS.
##
## Correct body:
##   <ChangeResourceRecordSetsRequest xmlns="...">
##     <ChangeBatch>...</ChangeBatch>
##   </ChangeResourceRecordSetsRequest>

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);

use_ok('Amazon::API');
use_ok('Amazon::API::NullLogger');
use_ok('Amazon::API::Botocore::Shape');
use_ok('Amazon::API::Botocore::Shape::Utils');

my $NS = 'https://route53.amazonaws.com/doc/2013-04-01/';

## Minimal ChangeResourceRecordSets-shaped model:
##   - HostedZoneId: uri-located, top-level member (goes in the path)
##   - ChangeBatch:  body member carrying the xmlNamespace; NO payload trait
my %shapes = (
  String => { type => 'string' },

  Change => {
    type     => 'structure',
    required => [qw(Action)],
    members  => { Action => { shape => 'String' }, },
  },

  Changes => {
    type   => 'list',
    member => { shape => 'Change', locationName => 'Change' },
  },

  ChangeBatch => {
    type     => 'structure',
    required => [qw(Changes)],
    members  => {
      Comment => { shape => 'String' },
      Changes => { shape => 'Changes' },
    },
  },

  ChangeResourceRecordSetsRequest => {
    type     => 'structure',
    required => [qw(HostedZoneId ChangeBatch)],
    members  => {
      HostedZoneId => { shape => 'String', location => 'uri', locationName => 'Id' },
      ChangeBatch  => { shape => 'ChangeBatch', xmlNamespace => { uri => $NS } },
    },
    ## NOTE: intentionally NO 'payload' key -- this is the path the fix covers.
  },
);

Amazon::API::Botocore::Shape::Utils::register_service_shapes( 'TestR53', \%shapes );

{

  package Amazon::API::TestR53;
  our @ISA = ('Amazon::API');
}

my $api = bless {
  botocore_metadata   => { protocol => 'rest-xml', },
  botocore_operations => {
    ChangeResourceRecordSets => {
      input => { shape => 'ChangeResourceRecordSetsRequest' },
      http  => {
        method     => 'POST',
        requestUri => '/2013-04-01/hostedzone/{Id}/rrset/',
      },
    },
  },
  service         => 'route53',
  botocore_shapes => \%shapes,
  logger          => Amazon::API::NullLogger->new,
  },
  'Amazon::API::TestR53';

$api->set_action('ChangeResourceRecordSets');

my $input_params = {
  HostedZoneId => 'Z3G1X4RV5M910V',
  ChangeBatch  => {
    Comment => 'website alias',
    Changes => [ { Action => 'UPSERT' } ],
  },
};

my $parameters = eval { $api->init_botocore_request($input_params) };

ok( !$EVAL_ERROR, 'init_botocore_request did not die' )
  or diag("error: $EVAL_ERROR");

ok( $parameters && ref $parameters eq 'HASH', 'returned a hashref' );

my $content = eval { $api->serialize_content($parameters) };

ok( !$EVAL_ERROR, 'serialize_content did not die (no multi-root guard croak)' )
  or diag("error: $EVAL_ERROR");

ok( $content, 'serialize_content produced non-empty content' );

## The fix: single operation-wrapper root, namespace as an attribute ON it.
like( $content, qr/<ChangeResourceRecordSetsRequest\b/, 'body root is the operation-wrapper element' );

like( $content, qr/<ChangeResourceRecordSetsRequest[^>]*\bxmlns="\Q$NS\E"/, 'xmlns is an attribute on the root element' );

like( $content, qr{<ChangeBatch>.*</ChangeBatch>}s, 'ChangeBatch is nested inside the root' );

## The regression signatures: no stray <_attr> sibling, and the namespace
## must NOT have leaked out as its own element.
unlike( $content, qr/<_attr\b/, 'no stray <_attr> element in the body' );
unlike( $content, qr{<xmlns>},  'xmlns did not leak out as an element' );

## uri-located member stays in the path, not the body.
unlike( $content, qr/<Id>/, 'uri-located HostedZoneId is not in the body' );

## Well-formedness: exactly one root element that parses cleanly.
SKIP: {
  eval { require XML::Twig; 1 }
    or skip 'XML::Twig not available', 1;

  my $ok = eval {
    my $body = $content;
    $body =~ s/^<[?]xml[^>]*[?]>\s*//xsm;
    XML::Twig->new->parse($body);
    1;
  };
  ok( $ok, 'serialized body is well-formed XML with a single root' )
    or diag("parse error: $EVAL_ERROR\n$content");
}

## The guard itself: generate_xml must refuse a multi-root structure
## rather than shipping malformed XML to AWS.
my $croaked = eval {
  $api->generate_xml( { ChangeBatch => { Comment => 'x' }, _attr => { xmlns => $NS } } );
  0;
} // 1;

ok( $croaked, 'generate_xml croaks on a multi-root (>1 top-level key) structure' );

done_testing;
