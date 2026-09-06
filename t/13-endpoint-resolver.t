#!/usr/bin/env perl

use strict;
use warnings;

use Amazon::API::EndpointResolver;

use Test::More;

my $partitions = {
  version    => '1.1',
  partitions => [
    { id      => 'aws',
      outputs => {
        dnsSuffix          => 'amazonaws.com',
        dualStackDnsSuffix => 'api.aws',
        name               => 'aws',
        supportsDualStack  => 1,
        supportsFIPS       => 1,
      },
      regionRegex => '^(us|eu|ap|sa|ca|me|af|il|mx)-\\w+-\\d+$',
      regions     => {
        'aws-global' => {},
        'us-east-1'  => {},
        'us-west-2'  => {},
      },
    },
    { id      => 'aws-us-gov',
      outputs => {
        dnsSuffix          => 'amazonaws.com',
        dualStackDnsSuffix => 'api.aws',
        name               => 'aws-us-gov',
        supportsDualStack  => 1,
        supportsFIPS       => 1,
      },
      regionRegex => '^us-gov-\\w+-\\d+$',
      regions     => {
        'us-gov-east-1' => {},
        'us-gov-west-1' => {},
      },
    },
  ],
};

my $rules = {
  version => '1.0',

  parameters => {
    Region => {
      type     => 'string',
      required => 1,
    },
    UseFIPS => {
      type     => 'boolean',
      required => 1,
      default  => 0,
    },
    UseDualStack => {
      type     => 'boolean',
      required => 1,
      default  => 0,
    },
  },

  rules => [
    { type       => 'tree',
      conditions => [
        { fn     => 'aws.partition',
          argv   => [ { ref => 'Region' } ],
          assign => 'PartitionResult',
        },
      ],
      rules => [
        { type       => 'endpoint',
          conditions => [
            { fn   => 'booleanEquals',
              argv => [ { ref => 'UseFIPS' }, 1, ],
            },
            { fn   => 'booleanEquals',
              argv => [ { ref => 'UseDualStack' }, 1, ],
            },
          ],
          endpoint => { url => 'https://sts-fips.{Region}.{PartitionResult#dualStackDnsSuffix}', },
        },
        { type       => 'endpoint',
          conditions => [
            { fn   => 'booleanEquals',
              argv => [ { ref => 'UseFIPS' }, 1, ],
            },
          ],
          endpoint => { url => 'https://sts-fips.{Region}.{PartitionResult#dnsSuffix}', },
        },
        { type       => 'endpoint',
          conditions => [
            { fn   => 'booleanEquals',
              argv => [ { ref => 'UseDualStack' }, 1, ],
            },
          ],
          endpoint => { url => 'https://sts.{Region}.{PartitionResult#dualStackDnsSuffix}', },
        },
        { type       => 'endpoint',
          conditions => [],
          endpoint   => { url => 'https://sts.{Region}.{PartitionResult#dnsSuffix}', },
        },
      ],
    },
    { type       => 'error',
      conditions => [],
      error      => 'Invalid Configuration: Missing Region',
    },
  ],
};

my $resolver = Amazon::API::EndpointResolver->new(
  endpoint_rule_set => $rules,
  partitions        => $partitions,
);

subtest 'standard regional endpoint' => sub {
  my $endpoint = $resolver->resolve( Region => 'us-east-1', );

  is( $endpoint->{url}, 'https://sts.us-east-1.amazonaws.com', 'standard endpoint', );
};

subtest 'FIPS endpoint' => sub {
  my $endpoint = $resolver->resolve(
    Region  => 'us-east-1',
    UseFIPS => 1,
  );

  is( $endpoint->{url}, 'https://sts-fips.us-east-1.amazonaws.com', 'FIPS endpoint', );
};

subtest 'dualstack endpoint' => sub {
  my $endpoint = $resolver->resolve(
    Region       => 'us-east-1',
    UseDualStack => 1,
  );

  is( $endpoint->{url}, 'https://sts.us-east-1.api.aws', 'dualstack endpoint', );
};

subtest 'FIPS dualstack endpoint' => sub {
  my $endpoint = $resolver->resolve(
    Region       => 'us-east-1',
    UseFIPS      => 1,
    UseDualStack => 1,
  );

  is( $endpoint->{url}, 'https://sts-fips.us-east-1.api.aws', 'FIPS dualstack endpoint', );
};

subtest 'partition selection' => sub {
  my $endpoint = $resolver->resolve( Region => 'us-gov-west-1', );

  is( $endpoint->{url}, 'https://sts.us-gov-west-1.amazonaws.com', 'GovCloud partition selected', );
};

done_testing;
