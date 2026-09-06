#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
  use Test::More;

  eval {

    require Amazon::API::S3;
    1;
  } or plan skip_all => 'no Amazon::API::S3 available';
}

########################################################################
subtest 'force path style => 0' => sub {
########################################################################
  my $s3 = Amazon::API::S3->new( region => 'us-east-1', );

  $s3->set_action('ListObjectsV2');

  my $request = $s3->create_botocore_request(
    parameters => { Bucket => 'my-bucket', },
    action     => 'ListObjectsV2',
  );

  $s3->_resolve_request_endpoint($request);

  $s3->init_botocore_request($request);

  is( $s3->get_url, 'https://my-bucket.s3.us-east-1.amazonaws.com', 'bucket moved into virtual-hosted endpoint', );

  is( $s3->get_request_uri, '?list-type=2', 'bucket removed from request URI', );

  is(
    $s3->get_url . $s3->get_request_uri,
    'https://my-bucket.s3.us-east-1.amazonaws.com?list-type=2',
    'virtual-hosted style produces correct final request URL',
  );
};

########################################################################
subtest 'force path style => 1' => sub {
########################################################################
  my $s3 = Amazon::API::S3->new(
    region               => 'us-east-1',
    use_force_path_style => 1,
  );

  $s3->set_action('ListObjectsV2');

  my $request = $s3->create_botocore_request(
    parameters => { Bucket => 'my-bucket', },
    action     => 'ListObjectsV2',
  );

  $s3->_resolve_request_endpoint($request);
  $s3->init_botocore_request($request);

  is(
    $s3->get_url,
    'https://s3.us-east-1.amazonaws.com/my-bucket',
    'force path style places bucket in resolved endpoint path',
  );

  is( $s3->get_request_uri, '?list-type=2', 'bucket removed from modeled request URI', );

  is(
    $s3->get_url . $s3->get_request_uri,
    'https://s3.us-east-1.amazonaws.com/my-bucket?list-type=2',
    'force path style produces correct final request URL',
  );

};

done_testing;

1;
