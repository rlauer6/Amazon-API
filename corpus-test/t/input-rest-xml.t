#!/usr/bin/env perl

use strict;
use warnings;

use lib q(lib);

use ProtocolTest;

use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);
use Data::Dumper;
use English qw(-no_match_vars);
use File::Basename qw(basename);
use Test::More;

my $program = basename($PROGRAM_NAME);

my ($test) = $program =~ m{^input[-]([^.]+)[.]t$}xsm;

die sprintf "ERROR: could not determine protocol test from %s\n", $PROGRAM_NAME
  if !$test;

my $tests = ProtocolTest->_test_load_corpus( 'input', $test, );

ok( $tests, sprintf 'loaded %s protocol test corpora', $test, );

my $protocol_file = sprintf 't/input-%s.pl', $test;

if ( -e $protocol_file ) {
  require "./$protocol_file";
}

my $input_test = defined &_input_test ? \&_input_test : \&_default_input_test;

########################################################################
for my $suite ( @{$tests} ) {
########################################################################

  die sprintf "ERROR: no shape for %s\n", Dumper($suite)
    if !$suite || !$suite->{shapes};

  register_service_shapes( ProtocolTest => $suite->{shapes}, );

  for my $case ( @{ $suite->{cases} } ) {
    next
      if $ENV{CASE_ID} && $case->{id} ne $ENV{CASE_ID};

    subtest $case->{id} => sub {

      if ( !exists $case->{serialized}->{body} ) {
        plan skip_all => 'case does not test serialized body';
      }

      my $operation = $case->{given};

      my $api = ProtocolTest->new(
        service             => 'protocol-test',
        version             => $suite->{metadata}->{apiVersion},
        botocore_metadata   => $suite->{metadata},
        botocore_operations => { $operation->{name} => $operation, },
        botocore_shapes     => $suite->{shapes},
        api_methods         => [ $operation->{name}, ],
        logger              => Log::Log4perl->get_logger,
        log_level           => $ENV{DEBUG} ? 'debug' : 'error',
      );

      $api->set_action( $operation->{name}, );

      my $parameters = $api->init_botocore_request( $case->{params}, );

      my $actual = $api->serialize_content($parameters);

      $input_test->( $api, $suite, $case, $actual, $case->{serialized}->{body}, );
    };
  }
}

done_testing();

########################################################################
sub _default_input_test {
########################################################################
  my ( $api, $suite, $case, $actual, $expected ) = @_;

  my $actual_body = $api->_test_normalize_json_body($actual);

  my $expected_body = $api->_test_normalize_json_body($expected);

  is_deeply( $actual_body, $expected_body, 'serialized body matches Botocore', )
    or diag Dumper(
    [ case     => $case->{id},
      actual   => $actual_body,
      expected => $expected_body,
    ]
    );

  return;
}

1;
