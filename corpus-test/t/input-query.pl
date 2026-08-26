use strict;
use warnings;

########################################################################
sub _input_test {
########################################################################
  my ( $api, $suite, $case, $actual, $expected ) = @_;

  my $actual_body = $api->_test_normalize_query_body($actual);

  my $expected_body = $api->_test_normalize_query_body($expected);

  my $shape_name = $case->{given}->{input}->{shape};

  $api->_test_canonicalize_query_maps( $actual_body, $suite->{shapes}, $shape_name, );

  $api->_test_canonicalize_query_maps( $expected_body, $suite->{shapes}, $shape_name, );

  $api->_test_normalize_idempotency_tokens( $actual_body, $expected_body, );

  is_deeply( $actual_body, $expected_body, 'serialized query body matches Botocore', )
    or diag Dumper(
    [ case     => $case->{id},
      actual   => $actual_body,
      expected => $expected_body,
    ]
    );

  return;
}

1;
