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

subtest '_uri_encode' => sub {
  is $resolver->_uri_encode('foo'),        'foo';
  is $resolver->_uri_encode('foo bar'),    'foo%20bar';
  is $resolver->_uri_encode('a/b'),        'a%2Fb';
  is $resolver->_uri_encode('a+b'),        'a%2Bb';
  is $resolver->_uri_encode('~foo_bar-1'), '~foo_bar-1';
};

done_testing;
