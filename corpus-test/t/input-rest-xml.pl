use strict;
use warnings;

########################################################################
sub _input_test {
########################################################################
  my ( $api, $suite, $case, $actual, $expected ) = @_;

  my $actual_body = $api->_test_normalize_xml_body($actual);

  my $expected_body = $api->_test_normalize_xml_body($expected);

  if ( $actual_body->{type} eq 'xml' && $expected_body->{type} eq 'xml' ) {
    my $shape_name = ( $case->{given}->{input} // {} )->{shape};

    $api->_test_canonicalize_xml_shape( $actual_body->{value}, $suite->{shapes}, $shape_name, );

    $api->_test_canonicalize_xml_shape( $expected_body->{value}, $suite->{shapes}, $shape_name, );
  }

  is_deeply( $actual_body, $expected_body, 'serialized XML body matches Botocore', )
    or diag Dumper(
    [ case     => $case->{id},
      actual   => $actual_body,
      expected => $expected_body,
    ]
    );

  return;
}

1;
