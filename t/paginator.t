use strict;
use warnings;

use Amazon::API::Paginator;

use English qw(-no_match_vars);
use JSON::PP;
use Test::More;

subtest 'token-driven pagination and original parameters' => sub {
  my $parameters = {
    Filter     => 'active',
    MaxResults => 2,
  };

  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'NextToken',
          output => { selectors => [ ['NextToken'] ] },
        },
      ],
      results => {
        append => [ ['Items'] ],
      },
      limit => 'MaxResults',
    },
    parameters => $parameters,
  );

  $paginator->add_page(
    {
      Items     => [ 'one', 'two' ],
      NextToken => 'page-2',
    }
  );

  ok( $paginator->has_next_page, 'first page has a continuation token' );

  is_deeply(
    $paginator->next_parameters,
    {
      Filter     => 'active',
      MaxResults => 2,
      NextToken  => 'page-2',
    },
    'next request starts with original parameters and applies token',
  );

  is_deeply(
    $parameters,
    {
      Filter     => 'active',
      MaxResults => 2,
    },
    'caller parameters are not modified',
  );

  $paginator->add_page(
    {
      Items => ['three'],
    }
  );

  ok( !$paginator->has_next_page, 'pagination stops without another token' );
  is( $paginator->next_parameters, undef, 'no next parameters after terminal page' );

  is_deeply(
    $paginator->result,
    {
      Items => [ 'one', 'two', 'three' ],
    },
    'list results are appended across pages',
  );
};

subtest 'fallback selector and explicit continuation' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'Marker',
          output => {
            selectors => [
              ['NextMarker'],
              [
                'Contents',
                { index => -1 },
                'Key',
              ],
            ],
          },
        },
      ],
      results => {
        append => [ ['Contents'] ],
      },
      continuation => {
        selectors => [ ['IsTruncated'] ],
      },
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      Contents => [
        { Key => 'alpha' },
        { Key => 'omega' },
      ],
      IsTruncated => JSON::PP::true,
      NextMarker  => q{},
    }
  );

  ok( $paginator->has_next_page, 'explicit continuation permits next page' );
  is_deeply(
    $paginator->next_parameters,
    { Marker => 'omega' },
    'fallback selector uses final content key',
  );

  $paginator->add_page(
    {
      Contents => [ { Key => 'last' } ],
      IsTruncated => JSON::PP::false,
      NextMarker  => 'ignored-marker',
    }
  );

  ok( !$paginator->has_next_page, 'explicit false continuation stops pagination' );
};

subtest 'multiple token fields replace and remove original values' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'StartName',
          output => { selectors => [ ['NextName'] ] },
        },
        {
          input  => 'StartType',
          output => { selectors => [ ['NextType'] ] },
        },
        {
          input  => 'StartIdentifier',
          output => { selectors => [ ['NextIdentifier'] ] },
        },
      ],
      results => {
        append => [ ['Records'] ],
      },
    },
    parameters => {
      Region          => 'example',
      StartIdentifier => 'old-id',
      StartName       => 'old-name',
      StartType       => 'old-type',
    },
  );

  $paginator->add_page(
    {
      NextIdentifier => 'next-id',
      NextName       => 'next-name',
      NextType       => undef,
      Records        => ['record'],
    }
  );

  is_deeply(
    $paginator->next_parameters,
    {
      Region          => 'example',
      StartIdentifier => 'next-id',
      StartName       => 'next-name',
    },
    'missing token removes its corresponding original request member',
  );
};

subtest 'nested result aggregation and first-page preservation' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'ExclusiveStartShardId',
          output => {
            selectors => [
              [
                'StreamDescription',
                'Shards',
                { index => -1 },
                'ShardId',
              ],
            ],
          },
        },
      ],
      results => {
        append => [
          [ 'StreamDescription', 'Shards' ],
        ],
      },
      continuation => {
        selectors => [
          [ 'StreamDescription', 'HasMoreShards' ],
        ],
      },
      preserve => [
        [ 'StreamDescription', 'StreamARN' ],
      ],
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      StreamDescription => {
        HasMoreShards => JSON::PP::true,
        Shards => [
          { ShardId => 'shard-1' },
          { ShardId => 'shard-2' },
        ],
        StreamARN => 'arn:first',
      },
    }
  );

  is_deeply(
    $paginator->next_parameters,
    { ExclusiveStartShardId => 'shard-2' },
    'nested indexed output token is evaluated',
  );

  $paginator->add_page(
    {
      StreamDescription => {
        HasMoreShards => JSON::PP::false,
        Shards        => [ { ShardId => 'shard-3' } ],
        StreamARN     => 'arn:second',
      },
    }
  );

  is_deeply(
    $paginator->result,
    {
      StreamDescription => {
        Shards => [
          { ShardId => 'shard-1' },
          { ShardId => 'shard-2' },
          { ShardId => 'shard-3' },
        ],
        StreamARN => 'arn:first',
      },
    },
    'nested list is aggregated and first-page metadata is preserved',
  );
};

subtest 'all result aggregation verbs' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'NextToken',
          output => { selectors => [ ['NextToken'] ] },
        },
      ],
      results => {
        add    => [ ['Count'] ],
        append => [ ['Items'] ],
        concat => [ ['Text'] ],
        first  => [
          ['MapValue'],
          ['Struct'],
        ],
      },
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      Count     => 2,
      Items     => [ 'a', 'b' ],
      MapValue  => { first => 1 },
      NextToken => 'next',
      Struct    => { Name => 'first' },
      Text      => 'ab',
    }
  );

  $paginator->add_page(
    {
      Count    => 3,
      Items    => ['c'],
      MapValue => { second => 1 },
      Struct   => { Name => 'second' },
      Text     => 'cd',
    }
  );

  is_deeply(
    $paginator->result,
    {
      Count    => 5,
      Items    => [ 'a', 'b', 'c' ],
      MapValue => { first => 1 },
      Struct   => { Name => 'first' },
      Text     => 'abcd',
    },
    'add append concat and first aggregation semantics are applied',
  );
};

subtest 'empty page can continue' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'NextToken',
          output => { selectors => [ ['NextToken'] ] },
        },
      ],
      results => {
        append => [ ['Items'] ],
      },
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      Items     => [],
      NextToken => 'next',
    }
  );

  ok( $paginator->has_next_page, 'empty result page does not terminate pagination' );

  $paginator->add_page(
    {
      Items => ['item'],
    }
  );

  is_deeply(
    $paginator->result,
    { Items => ['item'] },
    'empty list participates in aggregation correctly',
  );
};

subtest 'explicit continuation with no usable token stops' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'NextToken',
          output => { selectors => [ ['NextToken'] ] },
        },
      ],
      results => {
        append => [ ['Items'] ],
      },
      continuation => {
        selectors => [ ['HasMore'] ],
      },
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      HasMore   => JSON::PP::true,
      Items     => ['item'],
      NextToken => q{},
    }
  );

  ok(
    !$paginator->has_next_page,
    'true continuation without a usable token stops like Botocore',
  );
};

subtest 'repeated scalar token fails' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'NextToken',
          output => { selectors => [ ['NextToken'] ] },
        },
      ],
      results => {
        append => [ ['Items'] ],
      },
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      Items     => ['one'],
      NextToken => 'same',
    }
  );

  eval {
    $paginator->add_page(
      {
        Items     => ['two'],
        NextToken => 'same',
      }
    );
  };

  like(
    $EVAL_ERROR,
    qr/same\s+next\s+token\s+was\s+received\s+twice/xsm,
    'repeated token is rejected',
  );
};

subtest 'repeated map token fails by value' => sub {
  my $paginator = Amazon::API::Paginator->new(
    definition => {
      tokens => [
        {
          input  => 'ExclusiveStartKey',
          output => { selectors => [ ['LastEvaluatedKey'] ] },
        },
      ],
      results => {
        append => [ ['Items'] ],
      },
    },
    parameters => {},
  );

  $paginator->add_page(
    {
      Items => ['one'],
      LastEvaluatedKey => {
        PK => { S => 'key' },
      },
    }
  );

  eval {
    $paginator->add_page(
      {
        Items => ['two'],
        LastEvaluatedKey => {
          PK => { S => 'key' },
        },
      }
    );
  };

  like(
    $EVAL_ERROR,
    qr/same\s+next\s+token\s+was\s+received\s+twice/xsm,
    'map tokens are compared structurally',
  );
};

done_testing;
