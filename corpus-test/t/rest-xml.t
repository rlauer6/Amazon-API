#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Test::More;
use English qw(-no_match_vars);
use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);
use JSON qw(decode_json);

{

  package Amazon::API::ProtocolTest;
  use parent qw(Amazon::API);
}

########################################################################
sub canonicalize_xml_map_entry {
########################################################################
  my ( $entry, $shapes, $map_shape ) = @_;

  my $key_name = $map_shape->{key}->{locationName} // 'key';

  my $value_name = $map_shape->{value}->{locationName} // 'value';

  my $value_shape_name = $map_shape->{value}->{shape};

  my ($value_node) = grep { $_->{name} eq $value_name } @{ $entry->{children} };

  if ($value_node) {
    canonicalize_xml_shape( $value_node, $shapes, $value_shape_name, );
  }

  my %rank = (
    $key_name   => 0,
    $value_name => 1,
  );

  my @children = sort { ( $rank{ $a->{name} } // 2 ) <=> ( $rank{ $b->{name} } // 2 ) || $a->{name} cmp $b->{name} }
    @{ $entry->{children} };

  $entry->{children} = \@children;

  return;
}

########################################################################
sub xml_map_entry_key {
########################################################################
  my ( $entry, $map_shape ) = @_;

  my $key_name = $map_shape->{key}->{locationName} // 'key';

  my ($key) = grep { $_->{name} eq $key_name } @{ $entry->{children} };

  return q{}
    if !$key;

  return $key->{text} // q{};
}

########################################################################
sub canonicalize_xml_map {
########################################################################
  my ( $node, $shapes, $map_shape ) = @_;

  my @entries = @{ $node->{children} };

  for my $entry (@entries) {
    canonicalize_xml_map_entry( $entry, $shapes, $map_shape, );
  }

  @entries = sort { xml_map_entry_key( $a, $map_shape ) cmp xml_map_entry_key( $b, $map_shape ) } @entries;

  $node->{children} = \@entries;

  return;
}

########################################################################
sub canonicalize_flattened_xml_map {
########################################################################
  my ( $parent, $shapes, $map_shape, $member_name ) = @_;

  my @indexes;

  for my $idx ( 0 .. $#{ $parent->{children} } ) {
    push @indexes, $idx
      if $parent->{children}->[$idx]->{name} eq $member_name;
  }

  my @entries = map { $parent->{children}->[$_] } @indexes;

  for my $entry (@entries) {
    canonicalize_xml_map_entry( $entry, $shapes, $map_shape, );
  }

  @entries = sort { xml_map_entry_key( $a, $map_shape ) cmp xml_map_entry_key( $b, $map_shape ) } @entries;

  for my $idx ( 0 .. $#indexes ) {
    $parent->{children}->[ $indexes[$idx] ]
      = $entries[$idx];
  }

  return;
}

########################################################################
sub canonicalize_xml_shape {
########################################################################
  my ( $node, $shapes, $shape_name ) = @_;

  my $shape = $shapes->{$shape_name};

  return
    if !$shape;

  my $type = $shape->{type};

  if ( $type eq 'list' ) {
    my $member = $shape->{member};

    my $member_shape_name = $member->{shape};

    my $member_name = $member->{locationName} // 'member';

    for my $child ( @{ $node->{children} } ) {
      next
        if $child->{name} ne $member_name;

      canonicalize_xml_shape( $child, $shapes, $member_shape_name, );
    }

    return;
  }

  if ( $type eq 'map' ) {
    canonicalize_xml_map( $node, $shapes, $shape, );

    return;
  }

  return
    if $type ne 'structure'
    && $type ne 'union';

  for my $member ( keys %{ $shape->{members} // {} } ) {
    my $member_config = $shape->{members}->{$member};

    my $child_shape_name = $member_config->{shape};

    my $child_shape = $shapes->{$child_shape_name};

    next
      if !$child_shape;

    my $member_name = $member_config->{locationName} // $member;

    if ( $child_shape->{type} eq 'map'
      && $member_config->{flattened} ) {
      canonicalize_flattened_xml_map( $node, $shapes, $child_shape, $member_name, );

      next;
    }

    if ( $child_shape->{type} eq 'list' ) {
      my $item_shape_name = $child_shape->{member}->{shape};

      if ( $member_config->{flattened} ) {
        for my $child ( @{ $node->{children} } ) {
          next
            if $child->{name} ne $member_name;

          canonicalize_xml_shape( $child, $shapes, $item_shape_name, );
        }
      }
      else {
        for my $child ( @{ $node->{children} } ) {
          next
            if $child->{name} ne $member_name;

          canonicalize_xml_shape( $child, $shapes, $child_shape_name, );
        }
      }

      next;
    }

    for my $child ( @{ $node->{children} } ) {
      next
        if $child->{name} ne $member_name;

      canonicalize_xml_shape( $child, $shapes, $child_shape_name, );
    }
  }

  my @children = sort { $a->{name} cmp $b->{name} } @{ $node->{children} };

  $node->{children} = \@children;

  return;
}

########################################################################
sub normalize_xml_element {
########################################################################
  my ($element) = @_;

  my %attributes = %{ $element->atts // {} };

  my @children = grep { $_->gi ne '#PCDATA' } $element->children;

  my $text;

  if ( !@children ) {
    $text = $element->text;
  }

  return {
    name       => $element->gi,
    attributes => \%attributes,
    text       => $text,
    children   => [ map { normalize_xml_element($_) } @children ],
  };
}

########################################################################
sub normalize_xml {
########################################################################
  my ($xml) = @_;

  require XML::Twig;

  my $twig = XML::Twig->new( keep_spaces => 1, );

  $twig->parse($xml);

  return normalize_xml_element( $twig->root );
}

########################################################################
sub normalize_body {
########################################################################
  my ($body) = @_;

  $body //= q{};

  return {
    type  => 'empty',
    value => q{},
  } if $body eq q{};

  # XML declaration or an XML root both begin with '<'.
  if ( $body =~ /\A\s*</xsm ) {
    my $normalized = eval { return normalize_xml($body); };

    if ( !$EVAL_ERROR ) {
      return {
        type  => 'xml',
        value => $normalized,
      };
    }

    diag "XML normalization failed: $EVAL_ERROR";

    return {
      type  => 'invalid-xml',
      value => $body,
    };
  }

  return {
    type  => 'raw',
    value => $body,
  };
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

my $tests = load_corpus('input/rest-xml.json');

ok( ref $tests eq 'ARRAY', 'loaded rest-xml protocol test corpus', );

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

      my $parameters = $api->init_botocore_request( $case->{params}, );

      # protocol specific testing....
      my $actual = $api->serialize_content( $parameters, );
      $actual //= q{};

      my $actual_body = normalize_body($actual);

      my $expected_body = normalize_body( $case->{serialized}->{body}, );

      if ( $actual_body->{type} eq 'xml'
        && $expected_body->{type} eq 'xml' ) {
        my $shape_name
          = $case->{given}->{input}->{shape};

        canonicalize_xml_shape( $actual_body->{value}, $suite->{shapes}, $shape_name, );

        canonicalize_xml_shape( $expected_body->{value}, $suite->{shapes}, $shape_name, );
      }

      is_deeply( $actual_body, $expected_body, 'serialized body matches Botocore', ) or do {
        diag Dumper(
          [ case     => $case->{id},
            actual   => normalize_body($actual),
            expected => normalize_body( $case->{serialized}->{body} ),
          ]
        );

      };
    };
  }
}

done_testing;
