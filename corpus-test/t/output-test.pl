#!/usr/bin/env perl

use strict;
use warnings;

use lib q(lib);

use ProtocolTest;

use Amazon::API;
use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);
use Data::Dumper;
use English qw(-no_match_vars);
use File::Basename qw(basename);
use JSON::PP qw(decode_json);
use Test::More;

my $program = basename($PROGRAM_NAME);

my $type = 'output';

my ($test) = $program =~ m{^output[-]([^.]+)[.]t$}xsm;

die sprintf "ERROR: could not determine protocol test from %s\n", $PROGRAM_NAME
  if !$type || !$test;

my $tests = ProtocolTest->_test_load_corpus( $type, $test );

ok( $tests, sprintf 'loaded %s (%s) protocol test corpora', $test, $type );

########################################################################
for my $suite ( @{$tests} ) {
########################################################################

  die sprintf "ERROR: no shape for %s\n", Dumper($suite)
    if !$suite || !$suite->{shapes};

  register_service_shapes( ProtocolTest => $suite->{shapes}, );

  for my $case ( @{ $suite->{cases} } ) {
    next if $ENV{CASE_ID} && $case->{id} ne $ENV{CASE_ID};

    subtest $case->{id} => sub {

      if ( !exists $case->{result} ) {
        plan skip_all => 'case tests error response';
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

      my $response = $api->_test_create_response( $case->{response}, );

      my $actual = $api->decode_response( $response, );

      is_deeply( $actual, $case->{result}, 'deserialized response matches Botocore', )
        or diag Dumper(
        [ case     => $case->{id},
          actual   => $actual,
          expected => $case->{result},
        ]
        );
    };
  }
}

done_testing();

1;
