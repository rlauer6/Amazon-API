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

subtest 'locahost:5000' => sub {
  my $url = $resolver->_parse_url('http://localhost:5000/storage/v1/s3');

  is $url->{scheme},         'http';
  is $url->{authority},      'localhost:5000';
  is $url->{path},           '/storage/v1/s3';
  is $url->{normalizedPath}, '/storage/v1/s3/';
  is $url->{isIp},           0;
};

subtest 'ip' => sub {
  my $url = $resolver->_parse_url('https://127.0.0.1:4566');

  is $url->{authority},      '127.0.0.1:4566';
  is $url->{path},           q{};
  is $url->{normalizedPath}, '/';
  is $url->{isIp},           1;
};

done_testing;
