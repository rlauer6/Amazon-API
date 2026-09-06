use strict;
use warnings;

use Test::More;
use Amazon::API::EndpointContext::Compiler;
use List::Util qw(any);

my $compiler = Amazon::API::EndpointContext::Compiler->new;

is_deeply(
  $compiler->_compile_expression( 'BatchGetItem', 'ResourceArnList', 'keys(RequestItems)', ),
  { RequestItems => { _function => 'keys', }, },
  'compile keys()',
);

is_deeply(
  $compiler->_compile_expression( 'ImportTable', 'ResourceArn', 'TableCreationParameters.TableName', ),
  { TableCreationParameters => 'TableName', },
  'compile nested member',
);

is_deeply(
  $compiler->_compile_expression( 'TransactGetItems', 'ResourceArnList', 'TransactItems[*].Get.TableName', ),
  { TransactItems => [ { Get => 'TableName' }, ], },
  'compile projection',
);

is_deeply(
  $compiler->_compile_expression(
    'TransactWriteItems', 'ResourceArnList',
    'TransactItems[*].[ConditionCheck.TableName, Put.TableName, Delete.TableName, Update.TableName][]',
  ),
  { TransactItems =>
      [ { ConditionCheck => 'TableName' }, { Put => 'TableName' }, { Delete => 'TableName' }, { Update => 'TableName' }, ],
  },
  'compile projection with multiselect and flatten',
);

my $keys_expression = { RequestItems => { _function => 'keys', }, };

is_deeply(
  [ sort @{
      $compiler->evaluate(
        $keys_expression,
        { RequestItems => {
            Foo => {},
            Bar => {},
          },
        },
      )
    }
  ],
  [qw(Bar Foo)],
  'evaluate keys()',
);

my $nested_expression = { TableCreationParameters => 'TableName', };

is(
  $compiler->evaluate( $nested_expression, { TableCreationParameters => { TableName => 'example-table', }, }, ),
  'example-table', 'evaluate nested member',
);

my $projection_expression = { TransactItems => [ { Get => 'TableName' }, ], };

is_deeply(
  $compiler->evaluate(
    $projection_expression,
    { TransactItems => [ { Get => { TableName => 'table-a', }, }, { Get => { TableName => 'table-b', }, }, ], },
  ),
  [qw(table-a table-b)],
  'evaluate projection',
);

my $multiselect_expression = { TransactItems =>
    [ { ConditionCheck => 'TableName' }, { Put => 'TableName' }, { Delete => 'TableName' }, { Update => 'TableName' }, ], };

is_deeply(
  $compiler->evaluate(
    $multiselect_expression,
    { TransactItems => [
        { ConditionCheck => { TableName => 'table-a', },
          Put            => { TableName => 'table-b', },
        },
        { Delete => { TableName => 'table-c', },
          Update => { TableName => 'table-d', },
        },
      ],
    },
  ),
  [qw(table-a table-b table-c table-d)],
  'evaluate projection with multiselect and flatten',
);

is( $compiler->evaluate( { Foo => 'Bar' }, {}, ), undef, 'missing source returns undef', );

is( $compiler->evaluate( { Foo => 'Bar' }, { Foo => {}, }, ), undef, 'missing nested member returns undef', );

my @compile_failures = (
  { name  => 'operations must be a hash reference',
    input => [],
    match => qr/operations must be a hash reference/,
  },
  { name  => 'operationContextParams must be a hash reference',
    input => { Foo => { operationContextParams => [], }, },
    match => qr/operationContextParams for Foo must be a hash reference/,
  },
  { name  => 'context definition must be a hash reference',
    input => { Foo => { operationContextParams => { Bar => [], }, }, },
    match => qr/operationContextParams Bar for Foo must be a hash reference/,
  },
  { name  => 'context path is required',
    input => { Foo => { operationContextParams => { Bar => {}, }, }, },
    match => qr/operationContextParams Bar for Foo has no path/,
  },
  { name  => 'context path may not be empty',
    input => { Foo => { operationContextParams => { Bar => { path => q{}, }, }, }, },
    match => qr/operationContextParams Bar for Foo has no path/,
  },
);

foreach my $test (@compile_failures) {
  my $error;

  eval {
    $compiler->compile( $test->{input} );
    return 1;
  } or do {
    $error = $@;
  };

  like( $error, $test->{match}, $test->{name}, );
}
foreach my $path ( 'Foo..Bar', 'Foo[0]', 'Foo | Bar', 'length(Foo)', ) {
  my $error;

  eval {
    $compiler->_compile_expression( 'TestOperation', 'TestContext', $path, );
    return 1;
  } or do {
    $error = $@;
  };

  like( $error, qr/unsupported operation context path/, "reject unsupported expression: $path", );
}

{
  my $error;

  eval {
    $compiler->evaluate( { Foo => { _function => 'bogus', }, }, { Foo => {}, }, );
    return 1;
  } or do {
    $error = $@;
  };

  like( $error, qr/unsupported endpoint context function: bogus/, 'reject unsupported endpoint context function', );
}

{
  my $error;

  eval {
    $compiler->evaluate( { Foo => sub { return; }, }, { Foo => {}, }, );
    return 1;
  } or do {
    $error = $@;
  };

  like( $error, qr/unsupported compiled endpoint context expression/, 'reject unsupported compiled expression', );
}

done_testing;

1;
