package ProtocolTest;

use strict;
use warnings;

BEGIN {
  use Log::Log4perl;
  use Log::Log4perl::Level;

  Log::Log4perl->easy_init(
    { level  => $ENV{DEBUG} ? $DEBUG : $INFO,
      layout => '%F{1}-%L-%M: %m%n',
    }
  );
}

use Data::Dumper;
use English qw(-no_match_vars);
use HTTP::Response;
use JSON::PP qw(decode_json);
use List::Util qw(any);
use URI::Escape qw(uri_unescape);

use parent qw(Amazon::API);

########################################################################
sub _test_slurp {
########################################################################
  my ( $self, $filename ) = @_;

  open my $fh, '<', $filename
    or die sprintf "ERROR: could not open %s: %s\n", $filename, $OS_ERROR;

  local $INPUT_RECORD_SEPARATOR = undef;

  my $content = <$fh>;

  close $fh
    or die sprintf "ERROR: could not close %s: %s\n", $filename, $OS_ERROR;

  return $content;
}

########################################################################
sub _test_fetch_corpus {
########################################################################
  my ( $self, $filename ) = @_;

  return
    if !-e $filename;

  return decode_json( $self->_test_slurp($filename) );
}

########################################################################
sub _test_load_corpus {
########################################################################
  my ( $self, $type, $test ) = @_;

  if ( $ENV{DEBUG} ) {
    print {*STDERR} Dumper( [ type => $type, test => $test ] );
  }

  my ( $corpus_file, $extra_file ) = map { sprintf '%s/%s%s.json', $type, $test, $_ } ( q{}, '-extra' );

  die "ERROR: $corpus_file is required\n"
    if !-e $corpus_file;

  return [ map { @{ $self->_test_fetch_corpus($_) // [] } } ( $corpus_file, $extra_file ) ];
}

########################################################################
sub _test_create_response {
########################################################################
  my ( $self, $spec ) = @_;

  my $response = HTTP::Response->new( $spec->{status_code}, );

  for my $name ( keys %{ $spec->{headers} // {} } ) {
    $response->header( $name => $spec->{headers}->{$name}, );
  }

  $response->content( $spec->{body} // q{}, );

  return $response;
}

########################################################################
sub _test_normalize_json_body {
########################################################################
  my ( $self, $body ) = @_;

  return {
    type  => 'empty',
    value => q{},
    }
    if !defined $body || $body eq q{};

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

########################################################################
sub _test_normalize_query_body {
########################################################################
  my ( $self, $body ) = @_;

  $body //= q{};

  my @pairs;

  for my $pair ( split /&/xsm, $body ) {
    next
      if $pair eq q{};

    my ( $name, $value ) = split /=/xsm, $pair, 2;

    $name  //= q{};
    $value //= q{};

    $name  =~ tr/+/ /;
    $value =~ tr/+/ /;

    push @pairs, [ uri_unescape($name), uri_unescape($value), ];
  }

  @pairs = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @pairs;

  return \@pairs;
}

########################################################################
sub _test_normalize_idempotency_tokens {
########################################################################
  my ( $self, $actual, $expected ) = @_;

  my %expected = map { $_->[0] => $_->[1] } @{$expected};

  for my $pair ( @{$actual} ) {
    my ( $name, $value ) = @{$pair};

    next
      if !exists $expected{$name};

    next
      if $expected{$name} ne '00000000-0000-4000-8000-000000000000';

    next
      if $value !~ /^[0-9a-f]{8}[-][0-9a-f]{4}[-][0-9a-f]{4}[-][0-9a-f]{4}[-][0-9a-f]{12}$/ixsm;

    $pair->[1] = $expected{$name};
  }

  return;
}

########################################################################
sub _test_query_map_specs {
########################################################################
  my ( $self, $pairs, $shapes, $shape_name, $prefix ) = @_;

  return []
    if !defined $shape_name;

  $prefix //= q{};

  my $shape = $shapes->{$shape_name};

  return []
    if !$shape;

  my $type = $shape->{type} // q{};

  return []
    if $type ne 'structure'
    && $type ne 'union';

  my @specs;

  for my $member ( keys %{ $shape->{members} // {} } ) {
    my $config = $shape->{members}->{$member};

    my $child_shape_name = $config->{shape};

    next
      if !defined $child_shape_name;

    my $child = $shapes->{$child_shape_name};

    next
      if !$child;

    my $member_name = $config->{locationName} // $member;

    my $member_path
      = length $prefix
      ? sprintf '%s.%s', $prefix, $member_name
      : $member_name;

    my $member_prefix = sprintf '%s.', $member_path;

    my $has_member = any { $_->[0] eq $member_path || index( $_->[0], $member_prefix ) == 0 } @{$pairs};

    next
      if !$has_member;

    my $child_type = $child->{type} // q{};

    if ( $child_type eq 'map' ) {
      my $map_prefix
        = $config->{flattened}
        ? $member_path
        : sprintf '%s.entry', $member_path;

      my $key = $child->{key} // {};

      push @specs,
        {
        prefix   => $map_prefix,
        key_name => $key->{locationName} // 'key',
        };

      next;
    }

    if ( $child_type eq 'structure'
      || $child_type eq 'union' ) {
      push @specs, @{ $self->_test_query_map_specs( $pairs, $shapes, $child_shape_name, $member_path, ) };
    }
  }

  return \@specs;
}

########################################################################
sub _test_canonicalize_query_maps {
########################################################################
  my ( $self, $pairs, $shapes, $shape_name ) = @_;

  return
    if !defined $shape_name;

  my $specs = $self->_test_query_map_specs( $pairs, $shapes, $shape_name );

  for my $spec ( @{$specs} ) {
    my $prefix   = $spec->{prefix};
    my $key_name = $spec->{key_name};

    my %key_by_index;

    for my $pair ( @{$pairs} ) {
      my ( $name, $value ) = @{$pair};

      if ( $name =~ /^\Q$prefix\E[.](\d+)[.]\Q$key_name\E$/xsm ) {
        $key_by_index{$1} = $value;
      }
    }

    next
      if keys(%key_by_index) < 2;

    my %canonical_index;

    my $new_index = 1;

    for my $old_index ( sort { $key_by_index{$a} cmp $key_by_index{$b} || $a <=> $b } keys %key_by_index ) {
      $canonical_index{$old_index} = $new_index++;
    }

    for my $pair ( @{$pairs} ) {
      my $name = $pair->[0];

      next
        if $name !~ /^\Q$prefix\E[.](\d+)([.].*)$/xsm;

      my $old_index = $1;
      my $suffix    = $2;

      next
        if !exists $canonical_index{$old_index};

      $pair->[0] = sprintf '%s.%d%s', $prefix, $canonical_index{$old_index}, $suffix;
    }
  }

  @{$pairs} = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @{$pairs};

  return;
}

########################################################################
sub _test_canonicalize_xml_map_entry {
########################################################################
  my ( $self, $entry, $shapes, $map_shape ) = @_;

  my $key_name = $map_shape->{key}->{locationName} // 'key';

  my $value_name = $map_shape->{value}->{locationName} // 'value';

  my $value_shape_name = $map_shape->{value}->{shape};

  my ($value_node)
    = grep { $_->{name} eq $value_name } @{ $entry->{children} };

  if ($value_node) {
    $self->_test_canonicalize_xml_shape( $value_node, $shapes, $value_shape_name, );
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
sub _test_xml_map_entry_key {
########################################################################
  my ( $self, $entry, $map_shape ) = @_;

  my $key_name = $map_shape->{key}->{locationName} // 'key';

  my ($key)
    = grep { $_->{name} eq $key_name } @{ $entry->{children} };

  return q{}
    if !$key;

  return $key->{text} // q{};
}

########################################################################
sub _test_canonicalize_xml_map {
########################################################################
  my ( $self, $node, $shapes, $map_shape ) = @_;

  my @entries = @{ $node->{children} };

  for my $entry (@entries) {
    $self->_test_canonicalize_xml_map_entry( $entry, $shapes, $map_shape, );
  }

  @entries
    = sort { $self->_test_xml_map_entry_key( $a, $map_shape ) cmp $self->_test_xml_map_entry_key( $b, $map_shape ) } @entries;

  $node->{children} = \@entries;

  return;
}

########################################################################
sub _test_canonicalize_flattened_xml_map {
########################################################################
  my ( $self, $parent, $shapes, $map_shape, $member_name ) = @_;

  my @indexes;

  for my $idx ( 0 .. $#{ $parent->{children} } ) {
    push @indexes, $idx
      if $parent->{children}->[$idx]->{name} eq $member_name;
  }

  my @entries
    = map { $parent->{children}->[$_] } @indexes;

  for my $entry (@entries) {
    $self->_test_canonicalize_xml_map_entry( $entry, $shapes, $map_shape, );
  }

  @entries
    = sort { $self->_test_xml_map_entry_key( $a, $map_shape ) cmp $self->_test_xml_map_entry_key( $b, $map_shape ) } @entries;

  for my $idx ( 0 .. $#indexes ) {
    $parent->{children}->[ $indexes[$idx] ]
      = $entries[$idx];
  }

  return;
}

########################################################################
sub _test_canonicalize_xml_shape {
########################################################################
  my ( $self, $node, $shapes, $shape_name ) = @_;

  return
    if !defined $shape_name;

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

      $self->_test_canonicalize_xml_shape( $child, $shapes, $member_shape_name, );
    }

    return;
  }

  if ( $type eq 'map' ) {
    $self->_test_canonicalize_xml_map( $node, $shapes, $shape, );

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
      $self->_test_canonicalize_flattened_xml_map( $node, $shapes, $child_shape, $member_name, );

      next;
    }

    if ( $child_shape->{type} eq 'list' ) {
      my $item_shape_name = $child_shape->{member}->{shape};

      if ( $member_config->{flattened} ) {
        for my $child ( @{ $node->{children} } ) {
          next
            if $child->{name} ne $member_name;

          $self->_test_canonicalize_xml_shape( $child, $shapes, $item_shape_name, );
        }
      }
      else {
        for my $child ( @{ $node->{children} } ) {
          next
            if $child->{name} ne $member_name;

          $self->_test_canonicalize_xml_shape( $child, $shapes, $child_shape_name, );
        }
      }

      next;
    }

    for my $child ( @{ $node->{children} } ) {
      next
        if $child->{name} ne $member_name;

      $self->_test_canonicalize_xml_shape( $child, $shapes, $child_shape_name, );
    }
  }

  my @children = sort { $a->{name} cmp $b->{name} } @{ $node->{children} };

  $node->{children} = \@children;

  return;
}

########################################################################
sub _test_normalize_xml_element {
########################################################################
  my ( $self, $element ) = @_;

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
    children   => [ map { $self->_test_normalize_xml_element($_) } @children ],
  };
}

########################################################################
sub _test_normalize_xml_body {
########################################################################
  my ( $self, $body ) = @_;

  $body //= q{};

  return {
    type  => 'empty',
    value => q{},
    }
    if $body eq q{};

  if ( $body =~ /\A\s*</xsm ) {
    require XML::Twig;

    my $twig = XML::Twig->new( keep_spaces => 1, );

    my $ok = eval {
      $twig->parse($body);

      return 1;
    };

    if ($ok) {
      return {
        type  => 'xml',
        value => $self->_test_normalize_xml_element( $twig->root, ),
      };
    }

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

1;
