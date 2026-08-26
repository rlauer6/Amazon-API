use strict;
use warnings;

use Amazon::API::Paginator::Compiler;

use English qw(-no_match_vars);
use Test::More;

my $operations = {
  ListObjects => {
    input  => { shape => 'ListObjectsInput' },
    output => { shape => 'ListObjectsOutput' },
  },
  ListRecords => {
    input  => { shape => 'ListRecordsInput' },
    output => { shape => 'ListRecordsOutput' },
  },
  MixedResults => {
    input  => { shape => 'MixedResultsInput' },
    output => { shape => 'MixedResultsOutput' },
  },
  DescribeStream => {
    input  => { shape => 'DescribeStreamInput' },
    output => { shape => 'DescribeStreamOutput' },
  },
};

my $shapes = {
  Boolean => { type => 'boolean' },
  Integer => { type => 'integer' },
  Item => {
    type    => 'structure',
    members => {
      Key => { shape => 'String' },
    },
  },
  ItemList => {
    type   => 'list',
    member => { shape => 'Item' },
  },
  ListObjectsInput => {
    type    => 'structure',
    members => {
      Marker  => { shape => 'String' },
      MaxKeys => { shape => 'Integer' },
    },
  },
  ListObjectsOutput => {
    type    => 'structure',
    members => {
      CommonPrefixes => { shape => 'StringList' },
      Contents       => { shape => 'ItemList' },
      IsTruncated    => { shape => 'Boolean' },
      NextMarker     => { shape => 'String' },
      Prefix         => { shape => 'String' },
    },
  },
  ListRecordsInput => {
    type    => 'structure',
    members => {
      StartName       => { shape => 'String' },
      StartType       => { shape => 'String' },
      StartIdentifier => { shape => 'String' },
    },
  },
  ListRecordsOutput => {
    type    => 'structure',
    members => {
      NextName       => { shape => 'String' },
      NextType       => { shape => 'String' },
      NextIdentifier => { shape => 'String' },
      Records        => { shape => 'StringList' },
    },
  },
  Map => {
    type  => 'map',
    key   => { shape => 'String' },
    value => { shape => 'String' },
  },
  MixedResultsInput => {
    type    => 'structure',
    members => {
      NextToken => { shape => 'String' },
    },
  },
  MixedResultsOutput => {
    type    => 'structure',
    members => {
      Count     => { shape => 'Integer' },
      Items     => { shape => 'StringList' },
      MapValue  => { shape => 'Map' },
      NextToken => { shape => 'String' },
      Struct    => { shape => 'Struct' },
      Text      => { shape => 'String' },
    },
  },
  DescribeStreamInput => {
    type    => 'structure',
    members => {
      ExclusiveStartShardId => { shape => 'String' },
    },
  },
  DescribeStreamOutput => {
    type    => 'structure',
    members => {
      StreamDescription => { shape => 'StreamDescription' },
    },
  },
  Shard => {
    type    => 'structure',
    members => {
      ShardId => { shape => 'String' },
    },
  },
  ShardList => {
    type   => 'list',
    member => { shape => 'Shard' },
  },
  StreamDescription => {
    type    => 'structure',
    members => {
      HasMoreShards => { shape => 'Boolean' },
      Shards        => { shape => 'ShardList' },
      StreamARN     => { shape => 'String' },
    },
  },
  String => { type => 'string' },
  StringList => {
    type   => 'list',
    member => { shape => 'String' },
  },
  Struct => {
    type    => 'structure',
    members => {
      Name => { shape => 'String' },
    },
  },
};

my $compiler = Amazon::API::Paginator::Compiler->new(
  operations => $operations,
  shapes     => $shapes,
);

subtest 'fallback token and explicit continuation' => sub {
  my $compiled = $compiler->compile(
    {
      pagination => {
        ListObjects => {
          input_token        => 'Marker',
          output_token       => 'NextMarker || Contents[-1].Key',
          limit_key          => 'MaxKeys',
          more_results       => 'IsTruncated',
          result_key         => [ 'Contents', 'CommonPrefixes' ],
          non_aggregate_keys => [ 'Prefix' ],
        },
      },
    }
  );

  is_deeply(
    $compiled->{ListObjects},
    {
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
        append => [
          ['Contents'],
          ['CommonPrefixes'],
        ],
      },
      continuation => {
        selectors => [
          ['IsTruncated'],
        ],
      },
      limit => 'MaxKeys',
      preserve => [
        ['Prefix'],
      ],
    },
    'compiled fallback token paginator',
  );
};

subtest 'multiple tokens' => sub {
  my $compiled = $compiler->compile(
    {
      pagination => {
        ListRecords => {
          input_token => [
            'StartName',
            'StartType',
            'StartIdentifier',
          ],
          output_token => [
            'NextName',
            'NextType',
            'NextIdentifier',
          ],
          result_key => 'Records',
        },
      },
    }
  );

  is_deeply(
    $compiled->{ListRecords},
    {
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
    'compiled multiple token paginator',
  );
};

subtest 'result aggregation verbs' => sub {
  my $compiled = $compiler->compile(
    {
      version    => '1.0',
      pagination => {
        MixedResults => {
          input_token  => 'NextToken',
          output_token => 'NextToken',
          result_key   => [
            'Items',
            'Count',
            'Text',
            'MapValue',
            'Struct',
          ],
        },
      },
    }
  );

  is_deeply(
    $compiled->{MixedResults}->{results},
    {
      append => [ ['Items'] ],
      add    => [ ['Count'] ],
      concat => [ ['Text'] ],
      first  => [
        ['MapValue'],
        ['Struct'],
      ],
    },
    'compiled result keys by aggregation verb',
  );
};

subtest 'nested and indexed selectors' => sub {
  my $compiled = $compiler->compile(
    {
      pagination => {
        DescribeStream => {
          input_token        => 'ExclusiveStartShardId',
          output_token       => 'StreamDescription.Shards[-1].ShardId',
          more_results       => 'StreamDescription.HasMoreShards',
          result_key         => 'StreamDescription.Shards',
          non_aggregate_keys => [ 'StreamDescription.StreamARN' ],
        },
      },
    }
  );

  is_deeply(
    $compiled->{DescribeStream},
    {
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
    'compiled nested paginator paths',
  );
};

subtest 'unsupported metadata fails during compilation' => sub {
  eval {
    $compiler->compile(
      {
        pagination => {
          ListObjects => {
            input_token  => 'Marker',
            output_token => 'Contents[?Key].Key',
            result_key   => 'Contents',
          },
        },
      }
    );
  };

  like(
    $EVAL_ERROR,
    qr/unsupported\s+selector\s+in\s+ListObjects\s+output_token/xsm,
    'unsupported selector syntax fails',
  );

  eval {
    $compiler->compile(
      {
        pagination => {
          ListRecords => {
            input_token  => [ 'StartName', 'StartType' ],
            output_token => ['NextName'],
            result_key   => 'Records',
          },
        },
      }
    );
  };

  like(
    $EVAL_ERROR,
    qr/mismatched\s+input\/output\s+token\s+counts/xsm,
    'mismatched token counts fail',
  );

  eval {
    $compiler->compile(
      {
        pagination => {
          ListObjects => {
            input_token    => 'Marker',
            output_token   => 'NextMarker',
            result_key     => 'Contents',
            something_else => 'Nope',
          },
        },
      }
    );
  };

  like(
    $EVAL_ERROR,
    qr/unsupported\s+paginator\s+field\s+for\s+ListObjects:\s+something_else/xsm,
    'unknown paginator fields fail',
  );
};

done_testing;
