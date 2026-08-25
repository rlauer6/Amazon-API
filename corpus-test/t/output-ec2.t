#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use English qw(-no_match_vars);
use HTTP::Response;
use JSON::PP qw(decode_json);
use Test::More;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;

use Amazon::API;
use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);

{

  package Amazon::API::ProtocolTest;

  use parent qw(Amazon::API);
}

my $tests = load_corpus('output/ec2.json');

ok( $tests, 'loaded ec2 output protocol test corpus', );

Log::Log4perl->easy_init(
  { level  => $ENV{DEBUG} ? $DEBUG : $INFO,
    layout => '%F{1}-%L-%M: %m%n',
  }
);

for my $suite ( @{$tests} ) {

  die sprintf "no shape for %s\n", Dumper($suite)
    if !$suite || !$suite->{shapes};

  register_service_shapes( ProtocolTest => $suite->{shapes}, );

  for my $case ( @{ $suite->{cases} } ) {
    next if $ENV{CASE_ID} && $case->{id} ne $ENV{CASE_ID};

    subtest $case->{id} => sub {

      if ( !exists $case->{result} ) {
        plan skip_all => 'case tests error response';
      }

      my $operation = $case->{given};

      my $api = Amazon::API::ProtocolTest->new(
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

      my $response = create_response( $case->{response}, );

      my $actual = $api->decode_response( $response, );

      is_deeply( $actual, $case->{result}, 'deserialized rest-xml response matches Botocore', );
    };
  }
}

done_testing();

########################################################################
sub create_response {
########################################################################
  my ($spec) = @_;

  my $response = HTTP::Response->new( $spec->{status_code}, );

  for my $name ( keys %{ $spec->{headers} // {} } ) {
    $response->header( $name => $spec->{headers}->{$name}, );
  }

  $response->content( $spec->{body} // q{}, );

  return $response;
}

########################################################################
sub load_corpus {
########################################################################
  my ($filename) = @_;

  open my $fh, '<', $filename
    or die sprintf "could not open %s: %s\n",
    $filename,
    $OS_ERROR;

  local $INPUT_RECORD_SEPARATOR;

  my $content = <$fh>;

  close $fh
    or die sprintf "could not close %s: %s\n",
    $filename,
    $OS_ERROR;

  return decode_json($content);
}

1;
