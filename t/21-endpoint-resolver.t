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

is(
  $resolver->_get_attr( { resourceId => [ 'stream', 'my-stream', ], }, 'resourceId[0]', ),
  'stream', 'getAttr resolves array index',
);

is(
  $resolver->_get_attr( { resourceId => [ 'stream', 'my-stream', ], }, 'resourceId[1]', ),
  'my-stream', 'getAttr resolves second array index',
);

done_testing;
