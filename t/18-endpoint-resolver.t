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

subtest '_is_virutal_hostable_s3_bucket' => sub {
  is $resolver->_aws_is_virtual_hostable_s3_bucket( 'my-bucket',   0 ), 1;
  is $resolver->_aws_is_virtual_hostable_s3_bucket( 'MyBucket',    0 ), 0;
  is $resolver->_aws_is_virtual_hostable_s3_bucket( 'my_bucket',   0 ), 0;
  is $resolver->_aws_is_virtual_hostable_s3_bucket( '192.168.1.1', 0 ), 0;
  is $resolver->_aws_is_virtual_hostable_s3_bucket( 'foo..bar',    1 ), 0;
  is $resolver->_aws_is_virtual_hostable_s3_bucket( 'foo.bar',     0 ), 0;
  is $resolver->_aws_is_virtual_hostable_s3_bucket( 'foo.bar',     1 ), 1;
};

done_testing;
