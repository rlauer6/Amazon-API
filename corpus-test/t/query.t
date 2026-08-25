#!/usr/bin/env perl

use strict;
use warnings;

use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);
use English qw(-no_match_vars);
use JSON qw(decode_json);
use Test::More;
use URI::Escape qw(uri_unescape);

########################################################################
sub normalize_idempotency_tokens {
########################################################################
  my ( $actual, $expected, $shapes, $operation, $params ) = @_;

  my $input = $operation->{input};

  return
    if !$input || !defined $input->{shape};

  my $shape = $shapes->{ $input->{shape} };

  return
    if !$shape || $shape->{type} ne 'structure';

  for my $member ( keys %{ $shape->{members} // {} } ) {
    my $member_config = $shape->{members}->{$member};

    next
      if !$member_config->{idempotencyToken};

    # Explicit caller-supplied tokens must compare literally.
    next
      if exists $params->{$member};

    my $wire_name = $member_config->{locationName} // $member;

    my ($actual_parameter)
      = grep { $_->[0] eq $wire_name } @{$actual};

    my ($expected_parameter)
      = grep { $_->[0] eq $wire_name } @{$expected};

    next
      if !$actual_parameter || !$expected_parameter;

    # Only normalize something that really looks like a generated UUID.
    next
      if $actual_parameter->[1] !~ /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/ixsm;

    $actual_parameter->[1] = $expected_parameter->[1];
  }

  return;
}

########################################################################
sub collect_query_maps {
########################################################################
  my ( $shapes, $shape_name, $prefix, $member, $maps, $seen ) = @_;

  $seen //= {};

  my $shape = $shapes->{$shape_name};

  return
    if !$shape;

  return
    if $seen->{$shape_name};

  my %seen = %{$seen};
  $seen{$shape_name} = 1;

  my $type = $shape->{type};

  if ( $type eq 'structure' ) {

    for my $name ( keys %{ $shape->{members} // {} } ) {
      my $child_member = $shape->{members}->{$name};

      my $wire_name = $child_member->{locationName} // $name;

      my $child_prefix
        = length $prefix
        ? sprintf '%s.%s', $prefix, $wire_name
        : $wire_name;

      collect_query_maps( $shapes, $child_member->{shape}, $child_prefix, $child_member, $maps, \%seen, );
    }
  }
  elsif ( $type eq 'map' ) {

    push @{$maps},
      {
      prefix    => $prefix,
      flattened => $member->{flattened} ? 1 : 0,
      key_name  => $shape->{key}->{locationName} // 'key',
      };
  }

  return;
}

########################################################################
sub normalize_map_entries {
########################################################################
  my ( $parameters, $maps ) = @_;

  for my $map ( @{$maps} ) {

    my $prefix   = quotemeta $map->{prefix};
    my $key_name = quotemeta $map->{key_name};

    my $entry_re
      = $map->{flattened}
      ? qr{^${prefix}\.(\d+)\.${key_name}$}xsm
      : qr{^${prefix}\.entry\.(\d+)\.${key_name}$}xsm;

    my %entry_key;

    for my $parameter ( @{$parameters} ) {
      my ( $name, $value ) = @{$parameter};

      if ( $name =~ $entry_re ) {
        $entry_key{$1} = $value;
      }
    }

    my %canonical;

    my $index = 1;

    for my $entry ( sort { $entry_key{$a} cmp $entry_key{$b} || $a <=> $b } keys %entry_key ) {
      $canonical{$entry} = $index++;
    }

    for my $parameter ( @{$parameters} ) {
      my ($name) = @{$parameter};

      if ( $map->{flattened} ) {
        if ( $name =~ /^${prefix}\.(\d+)\./xsm ) {
          my $entry = $1;

          if ( exists $canonical{$entry} ) {
            $name =~ s{
          ^${prefix}\.\Q$entry\E\.
        }{
          $map->{prefix}
            . q{.}
            . $canonical{$entry}
            . q{.}
        }exsm;
          }
        }
      }
      else {
        if ( $name =~ /^${prefix}\.entry\.(\d+)\./xsm ) {
          my $entry = $1;

          if ( exists $canonical{$entry} ) {
            $name =~ s{
          ^${prefix}\.entry\.\Q$entry\E\.
        }{
          $map->{prefix}
            . q{.entry.}
            . $canonical{$entry}
            . q{.}
        }exsm;
          }
        }
      }

      $parameter->[0] = $name;
    }
  }

  return;
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

########################################################################
sub normalize_query {
########################################################################
  my ( $query, $maps ) = @_;

  my @parameters;

  for my $pair ( split /&/xsm, $query ) {
    my ( $key, $value ) = split /=/xsm, $pair, 2;

    push @parameters, [ uri_unescape($key), uri_unescape( $value // q{} ), ];
  }

  normalize_map_entries( \@parameters, $maps, );

  @parameters
    = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @parameters;

  return \@parameters;
}

########################################################################
{

  package Amazon::API::ProtocolTest;

  use parent qw(Amazon::API);
}
########################################################################

my $tests = load_corpus('input/query.json');

ok( ref $tests eq 'ARRAY', 'loaded query protocol test corpus', );

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
        api_methods         => [ $operation->{name} ],
      );

      $api->set_action( $operation->{name}, );

      my @maps;

      my $input = $operation->{input};

      if ( $input && defined $input->{shape} ) {
        collect_query_maps( $suite->{shapes}, $input->{shape}, q{}, {}, \@maps, );
      }

      my $parameters = $api->init_botocore_request( $case->{params}, );

      my $actual = $api->serialize_content( $parameters, );

      my $actual_query = normalize_query( $actual, \@maps, );

      my $expected_query
        = normalize_query( $case->{serialized}->{body}, \@maps, );

      normalize_idempotency_tokens( $actual_query, $expected_query, $suite->{shapes}, $operation, $case->{params}, );

      is_deeply( $actual_query, $expected_query, 'serialized query body matches Botocore', );
    };
  }
}

done_testing;

1;
