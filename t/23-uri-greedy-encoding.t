#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

BEGIN {
  eval {
    require Amazon::API::S3Control;
    require Amazon::API::S3;
    1;
  } or plan skip_all => 'no Amazon::API::S3 or Amazon::API::S3Control';
}

########################################################################
subtest 'non-greedy URI label is percent encoded' => sub {
########################################################################
  my $s3control = Amazon::API::S3Control->new(
    aws_access_key_id     => 'test',
    aws_secret_access_key => 'test',
    region                => 'us-east-1',
    client_context_params => { UseArnRegion => 1 }
  );

  $s3control->set_action('GetAccessPoint');

  my $access_point_name = 'arn:aws:s3-outposts:us-west-2:123456789012:outpost/op-0123456789abcdef0/accesspoint/test-ap';

  my $request = $s3control->create_botocore_request(
    parameters => {
      Name      => $access_point_name,
      AccountId => '123456789012'
    },
    action => 'GetAccessPoint',
  );

  $s3control->_resolve_request_endpoint($request);

  my $content = $s3control->init_botocore_request($request);

  my $url = $s3control->get_url;

  ok( $url =~ /us[-]west[-]2/, 'region is not configured region' );

  my $request_uri = $s3control->get_request_uri;

  my $expected
    = '/v20180820/accesspoint/'
    . 'arn%3Aaws%3As3-outposts%3Aus-west-2%3A123456789012'
    . '%3Aoutpost%2Fop-0123456789abcdef0%2Faccesspoint%2Ftest-ap';

  is( $request_uri, $expected, 'non-greedy URI label percent encodes reserved characters' );
};

########################################################################
subtest 'greedy URI label preserves slash but encodes other reserved characters' => sub {
########################################################################
  my $s3 = Amazon::API::S3->new(
    region                => 'us-east-1',
    aws_access_key_id     => 'test',
    aws_secret_access_key => 'test',
  );

  $s3->set_action('GetObject');

  my $request = $s3->create_botocore_request(
    parameters => {
      Bucket => 'my-bucket',
      Key    => 'photos/2026/my file.txt',
    },
    action => 'GetObject',
  );

  $s3->_resolve_request_endpoint($request);

  my $content = $s3->init_botocore_request($request);

  # modeled template: /{Bucket}/{Key+}
  # Key: photos/2026/my file.txt
  is( $s3->get_request_uri, '/photos/2026/my%20file.txt', 'greedy URI label preserves slash and percent encodes spaces', );
};

done_testing;

1;
