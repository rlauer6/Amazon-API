#!/usr/bin/env perl

use strict;
use warnings;

use Amazon::API;
use Amazon::API::Botocore::Shape::Utils qw(
  register_service_shapes
);

use Data::Dumper;
use English qw(-no_match_vars);
use JSON::PP;
use Test::More;

{

  package Amazon::API::ProtocolTest;

  use parent qw(Amazon::API);
}

########################################################################
sub load_corpus {
########################################################################
  my ($file) = @_;

  open my $fh, '<', $file
    or die sprintf 'could not open %s: %s', $file, $OS_ERROR;

  local $INPUT_RECORD_SEPARATOR = undef;
  my $json = <$fh>;

  close $fh
    or die sprintf 'could not close %s: %s', $file, $OS_ERROR;

  return decode_json($json);
}

my $tests = load_corpus('input/rest-json.json');

ok( $tests, 'loaded rest-json protocol test corpus', );

for my $suite ( @{$tests} ) {

  register_service_shapes( ProtocolTest => $suite->{shapes}, );

  for my $case ( @{ $suite->{cases} } ) {
    subtest $case->{id} => sub {

      if ( !exists $case->{serialized}->{body} ) {
        plan skip_all => 'case does not test serialized body';
      }

      my $operation = $case->{given};

      my $api = Amazon::API::ProtocolTest->new(
        service             => 'protocol-test',
        version             => $suite->{metadata}->{apiVersion},
        botocore_metadata   => $suite->{metadata},
        botocore_operations => { $operation->{name} => $operation, },
        botocore_shapes     => $suite->{shapes},
        api_methods         => [ $operation->{name}, ],
      );

      $api->set_action( $operation->{name}, );

      my $parameters = $api->init_botocore_request( $case->{params}, );

      my $actual = $api->serialize_content( $parameters, );

      $actual //= q{};

      my $actual_body = normalize_json_body($actual);

      my $expected_body = normalize_json_body( $case->{serialized}->{body}, );

      is_deeply( $actual_body, $expected_body, 'serialized body matches Botocore', )
        or diag Dumper(
        [ case     => $case->{id},
          actual   => $actual_body,
          expected => $expected_body,
        ]
        );
    };
  }
}

done_testing();

########################################################################
sub normalize_json_body {
########################################################################
  my ($body) = @_;

  return {
    type  => 'empty',
    value => q{},
    }
    if !defined $body
    || $body eq q{};

  my $decoded;

  my $ok = eval {
    $decoded = decode_json($body);

    return 1;
  };

  if ($ok) {
    return {
      type  => 'json',
      value => $decoded,
    };
  }

  return {
    type  => 'raw',
    value => $body,
  };
}

1;
