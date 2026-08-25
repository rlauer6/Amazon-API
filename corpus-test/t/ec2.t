#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use English qw(-no_match_vars);
use JSON::PP qw(decode_json);
use Test::More;

use Amazon::API;
use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);

{

  package Amazon::API::ProtocolTest;

  use parent qw(Amazon::API);
}

my $tests = load_corpus('input/ec2.json');

ok( $tests, 'loaded ec2 protocol test corpus', );

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

      my $actual_body = normalize_query($actual);
      if ( $case->{id}
        && $case->{id} eq 'Ec2ProtocolIdempotencyTokenAutoFill' ) {
        for my $pair ( @{$actual_body} ) {
          next
            if $pair->[0] ne 'Token';

          $pair->[1] = '00000000-0000-4000-8000-000000000000';

          last;
        }
      }
      my $expected_body = normalize_query( $case->{serialized}->{body}, );

      is_deeply( $actual_body, $expected_body, 'serialized ec2 body matches Botocore', )
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

########################################################################
sub normalize_query {
########################################################################
  my ($body) = @_;

  return []
    if !defined $body
    || $body eq q{};

  my @pairs;

  for my $part ( split /&/xsm, $body ) {
    my ( $key, $value ) = split /=/xsm, $part, 2;

    $value //= q{};

    push @pairs, [ $key, $value, ];
  }

  @pairs
    = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @pairs;

  return \@pairs;
}

1;
