#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
  use Test::More;
  eval {
    require Amazon::API::Kinesis;
    1;
  } or do {
    plan skip_all => 'Amazon::API::Kinesis unavailable';
  };
}

########################################################################
subtest 'kinesis endpoint' => sub {
########################################################################
  my $kinesis = Amazon::API::Kinesis->new(
    region                => 'us-east-1',
    aws_access_key_id     => 'test',
    aws_secret_access_key => 'test',
    order                 => [],
  );

  $kinesis->set_action('ListShards');

  my $request = $kinesis->create_botocore_request(
    parameters => { StreamARN => 'arn:aws:kinesis:us-east-1:123456789012:stream/my-stream', },
    action     => 'ListShards',
  );

  $kinesis->_resolve_request_endpoint($request);

  my $content = $kinesis->init_botocore_request($request);

  my $url = $kinesis->get_url;

  is( $url, 'https://123456789012.control-kinesis.us-east-1.amazonaws.com' );
};

done_testing;

1;
