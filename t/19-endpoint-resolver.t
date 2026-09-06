#!/usr/bin/env perl

use strict;
use warnings;

use Amazon::API::EndpointResolver;

use CLI::Simple::Utils qw(slurp_json);
use Test::More;

my $botocore = $ENV{BOTOCORE_PATH}
  or plan skip_all => 'BOTOCORE_PATH not set';

my $rules = slurp_json("$botocore/botocore/data/sts/2011-06-15/endpoint-rule-set-1.json");

my $partitions = slurp_json("$botocore/botocore/data/partitions.json");

my $resolver = Amazon::API::EndpointResolver->new(
  endpoint_rule_set => $rules,
  partitions        => $partitions,
);

subtest 'accesspoint' => sub {
  my $arn = $resolver->_aws_parse_arn('arn:aws:s3:us-east-1:123456789012:accesspoint/my-ap');

  is $arn->{partition}, 'aws';
  is $arn->{service},   's3';
  is $arn->{region},    'us-east-1';
  is $arn->{accountId}, '123456789012';
  is_deeply $arn->{resourceId}, [ 'accesspoint', 'my-ap' ];
};

subtest 'outpost' => sub {
  my $arn = $resolver->_aws_parse_arn('arn:aws:s3-outposts:us-east-1:123456789012:outpost/op-123/accesspoint/my-ap');

  is_deeply $arn->{resourceId}, [ 'outpost', 'op-123', 'accesspoint', 'my-ap' ];
};

subtest 'invalid' => sub {
  ok !defined $resolver->_aws_parse_arn('not-an-arn');
};

done_testing;
