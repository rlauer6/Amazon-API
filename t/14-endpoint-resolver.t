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

subtest 'regional' => sub {
  my $endpoint = $resolver->resolve( Region => 'us-east-1', );

  is( $endpoint->{url}, 'https://sts.us-east-1.amazonaws.com', 'regional STS endpoint', );
};

subtest 'aws-global' => sub {
  my $endpoint = $resolver->resolve( Region => 'aws-global', );

  is( $endpoint->{url}, 'https://sts.amazonaws.com', 'global STS endpoint', );

  is( $endpoint->{properties}->{authSchemes}->[0]->{signingRegion}, 'us-east-1', 'global endpoint signs in us-east-1', );
};

subtest 'FIPS' => sub {
  my $endpoint = $resolver->resolve(
    Region  => 'us-east-1',
    UseFIPS => 1,
  );

  is( $endpoint->{url}, 'https://sts-fips.us-east-1.amazonaws.com', 'FIPS endpoint', );
};

subtest 'DualStack' => sub {
  my $endpoint = $resolver->resolve(
    Region       => 'us-east-1',
    UseDualStack => 1,
  );

  is( $endpoint->{url}, 'https://sts.us-east-1.api.aws', 'DualStack endpoint', );
};

subtest 'FIPS + DualStack' => sub {
  my $endpoint = $resolver->resolve(
    Region       => 'us-east-1',
    UseFIPS      => 1,
    UseDualStack => 1,
  );

  is( $endpoint->{url}, 'https://sts-fips.us-east-1.api.aws', 'FIPS DualStack endpoint', );
};

subtest 'GovCloud' => sub {
  my $endpoint = $resolver->resolve( Region => 'us-gov-west-1', );

  is( $endpoint->{url}, 'https://sts.us-gov-west-1.amazonaws.com', 'GovCloud endpoint', );
};

subtest 'custom endpoint' => sub {
  my $endpoint = $resolver->resolve(
    Region   => 'us-east-1',
    Endpoint => 'https://example.invalid',
  );

  is( $endpoint->{url}, 'https://example.invalid', 'custom endpoint', );
};

subtest 'custom endpoint + FIPS rejected' => sub {
  eval { $resolver->resolve( Region => 'us-east-1', Endpoint => 'https://example.invalid', UseFIPS => 1, ); };

  like( $@, qr/FIPS.*custom endpoint/is, 'custom endpoint with FIPS rejected', );
};

subtest 'missing region rejected' => sub {
  eval { $resolver->resolve(); };

  like( $@, qr/Missing Region|Region.*required/is, 'missing region rejected', );
};

done_testing;
