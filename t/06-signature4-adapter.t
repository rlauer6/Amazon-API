#!/usr/bin/env perl

## t/06-signature4-adapter.t
##
## Confirms Amazon::API::Signature4 correctly adapts between
## Amazon::API.pm's AWS::Signature4-style interface (HTTP::Request
## object, dash-prefix constructor args) and Amazon::Signature4::Lite
## (plain hashrefs, no LWP dependency).

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);
use HTTP::Request;
use URI;

use_ok('Amazon::Signature4::Lite');
use_ok('Amazon::API::Signature4');

## known-good test vector from AWS SigV4 documentation
## https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
my $ACCESS_KEY = 'AKIDEXAMPLE';
my $SECRET_KEY = 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY';
my $REGION     = 'us-east-1';
my $SERVICE    = 'iam';

## construct with dash-prefix keys (AWS::Signature4 convention, used by Amazon::API.pm)
my $signer = eval {
  Amazon::API::Signature4->new(
    -access_key => $ACCESS_KEY,
    -secret_key => $SECRET_KEY,
    region      => $REGION,
    service     => $SERVICE,
  );
};

ok( $signer && !$EVAL_ERROR, 'new() with dash-prefix keys succeeds' )
  or BAIL_OUT("construction failed: $EVAL_ERROR");

isa_ok( $signer, 'Amazon::API::Signature4' );
isa_ok( $signer, 'Amazon::Signature4::Lite' );

## also confirm plain-key construction works
my $signer2 = eval {
  Amazon::API::Signature4->new(
    access_key => $ACCESS_KEY,
    secret_key => $SECRET_KEY,
    region     => $REGION,
    service    => $SERVICE,
  );
};

ok( $signer2 && !$EVAL_ERROR, 'new() with plain keys also succeeds' );

## construct an HTTP::Request and sign it (the interface Amazon::API.pm uses)
my $request = HTTP::Request->new( GET => 'https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08', );
$request->header( 'Content-Type' => 'application/x-www-form-urlencoded' );

my $signed = eval { $signer->sign( $request, $REGION ) };

ok( !$EVAL_ERROR, 'sign($http_request, $region) does not die' )
  or diag("error: $EVAL_ERROR");

## sign() should return the same HTTP::Request object (in-place mutation)
is( $signed, $request, 'sign() returns the same HTTP::Request object' );

## Authorization header must be present and correctly shaped
my $auth = $request->header('Authorization');
ok( $auth, 'Authorization header was set on the request' );
like( $auth, qr/^AWS4-HMAC-SHA256\s+Credential=/, 'Authorization has correct scheme' );
like( $auth, qr/Credential=AKIDEXAMPLE\//,        'Authorization contains access key' );
like( $auth, qr|/$REGION/$SERVICE/aws4_request|,  'Authorization contains correct scope' );
like( $auth, qr/SignedHeaders=/,                  'Authorization contains SignedHeaders' );
like( $auth, qr/Signature=[0-9a-f]{64}/,          'Authorization contains 64-char hex signature' );

## x-amz-date must be set
my $amz_date = $request->header('x-amz-date');
ok( $amz_date, 'x-amz-date header was set' );
like( $amz_date, qr/^\d{8}T\d{6}Z$/, 'x-amz-date has correct format' );

## session_token path
my $signer3 = Amazon::API::Signature4->new(
  -access_key     => $ACCESS_KEY,
  -secret_key     => $SECRET_KEY,
  -security_token => 'test-session-token',
  region          => $REGION,
  service         => $SERVICE,
);

my $request2 = HTTP::Request->new( GET => 'https://iam.amazonaws.com/?Action=ListUsers' );
eval { $signer3->sign( $request2, $REGION ) };

ok( !$EVAL_ERROR,                              'sign() with session_token does not die' );
ok( $request2->header('x-amz-security-token'), 'x-amz-security-token header set when session_token present' );
is( $request2->header('x-amz-security-token'), 'test-session-token', 'x-amz-security-token has correct value' );

## parse_service_url inherited from Amazon::Signature4::Lite
my ( $host, $service, $region ) = Amazon::API::Signature4->parse_service_url(
  host           => 'sns.us-east-1.amazonaws.com',
  default_region => 'us-east-1',
);

is( $service, 'sns',       'parse_service_url: service extracted correctly' );
is( $region,  'us-east-1', 'parse_service_url: region extracted correctly' );

## confirm disable_double_encoding is passed through to
## Amazon::Signature4::Lite
my $signer4 = eval {
  Amazon::API::Signature4->new(
    access_key              => $ACCESS_KEY,
    secret_key              => $SECRET_KEY,
    region                  => $REGION,
    service                 => 's3-outposts',
    disable_double_encoding => 1,
  );
};

ok( $signer4 && !$EVAL_ERROR, 'new() with disable_double_encoding succeeds', );

ok( $signer4->{disable_double_encoding}, 'disable_double_encoding is passed through to Amazon::Signature4::Lite', );

done_testing;
