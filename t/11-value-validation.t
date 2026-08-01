#!/usr/bin/env perl

## Regression test for request-side value validation (enum/min/max/pattern)
## and the $Amazon::API::VALIDATE_MODE toggle. Drives REAL shape construction
## (->new -> _init_*), which is where validation fires in production. No AWS.
##
## Modes: 'strict' (default) croaks with escape-hatch guidance; 'warn' carps and
## passes the value through (stale-metadata-safe); 'off' skips. Override per-call
## by localizing the global:  local $Amazon::API::VALIDATE_MODE = 'off';

use strict;
use warnings;

use Test::More;
use English qw(-no_match_vars);

use_ok('Amazon::API::Botocore::Shape');

# canonical global lives in Amazon::API; define it here so the read resolves
## global set fully-qualified below (canonical name is $Amazon::API::VALIDATE_MODE)

sub mk {   # construct a shape, returning ($ok, $err)
  my (%def) = @_;
  my $ok = eval {
    Amazon::API::Botocore::Shape->new( { service => 't', %def } );
    1;
  };
  return ( $ok, $EVAL_ERROR );
}

my $enum = [qw(amd nvidia xilinx habana)];

#### enum ###############################################################
$Amazon::API::VALIDATE_MODE = 'strict';

my ( $ok, $err ) = mk( type => 'string', enum => $enum, _value => 'nvidia' );
ok( $ok, 'strict: valid enum value constructs' );

( $ok, $err ) = mk( type => 'string', enum => $enum, _value => 'intel' );
ok( !$ok, 'strict: invalid enum value croaks at construction' );
like( $err, qr/not\ one\ of\ the\ allowed\ values/x, 'strict: message names the violation' );
like( $err, qr/amd.*nvidia.*xilinx.*habana/xs, 'strict: lists all allowed values' );
like( $err, qr/\$Amazon::API::VALIDATE_MODE/x, 'strict: exception names the toggle' );
like( $err, qr/'warn'\ or\ 'off'/x, 'strict: exception offers the escape hatch' );

#### warn passes through ################################################
{
  local $Amazon::API::VALIDATE_MODE = 'warn';
  my @w;
  local $SIG{__WARN__} = sub { push @w, "@_" };
  ( $ok, $err ) = mk( type => 'string', enum => $enum, _value => 'intel' );
  ok( $ok, 'warn: invalid enum value constructs (passes through)' );
  like( "@w", qr/not\ one\ of\ the\ allowed\ values/x, 'warn: carps the message' );
  unlike( "@w", qr/VALIDATE_MODE/x, 'warn: no strict-only guidance in the carp' );
}

#### off is silent #####################################################
{
  local $Amazon::API::VALIDATE_MODE = 'off';
  my @w;
  local $SIG{__WARN__} = sub { push @w, "@_" };
  ( $ok, $err ) = mk( type => 'string', enum => $enum, _value => 'intel' );
  ok( $ok, 'off: invalid enum value constructs' );
  is( scalar @w, 0, 'off: silent' );
}

#### local restores the outer mode #####################################
is( $Amazon::API::VALIDATE_MODE, 'strict',
  'local override restored to strict after block' );

#### toggle reaches the PRE-EXISTING checks, not just enum #############
# string length min/max
$Amazon::API::VALIDATE_MODE = 'strict';
( $ok, $err ) = mk( type => 'string', min => 3, max => 5, _value => 'ab' );
ok( !$ok, 'strict: string under min length croaks' );
like( $err, qr/length\ of\ value\ must\ be\ >=\ 3/x, 'strict: min-length message' );

( $ok, $err ) = mk( type => 'string', min => 3, max => 5, _value => 'abcdef' );
ok( !$ok, 'strict: string over max length croaks' );

{
  local $Amazon::API::VALIDATE_MODE = 'off';
  ( $ok, $err ) = mk( type => 'string', min => 3, max => 5, _value => 'ab' );
  ok( $ok, 'off: min/max reaches pre-existing string check (passes)' );
}

# integer min/max
$Amazon::API::VALIDATE_MODE = 'strict';
( $ok, $err ) = mk( type => 'integer', min => 1, max => 10, _value => 42 );
ok( !$ok, 'strict: integer over max croaks' );
like( $err, qr/value\ must\ be\ <=\ 10/x, 'strict: integer max message' );

{
  local $Amazon::API::VALIDATE_MODE = 'off';
  ( $ok, $err ) = mk( type => 'integer', min => 1, max => 10, _value => 42 );
  ok( $ok, 'off: integer min/max toggles too' );
}

#### pattern through the toggle (regression: list-context match bug) ####
$Amazon::API::VALIDATE_MODE = 'strict';
( $ok, $err ) = mk( type => 'string', pattern => '^[0-9]+$', _value => 'abc' );
ok( !$ok, 'strict: pattern mismatch croaks (guards list-context match bug)' );

( $ok, $err ) = mk( type => 'string', pattern => '^[0-9]+$', _value => '123' );
ok( $ok, 'strict: pattern match constructs cleanly' );

{
  local $Amazon::API::VALIDATE_MODE = 'off';
  ( $ok, $err ) = mk( type => 'string', pattern => '^[0-9]+$', _value => 'abc' );
  ok( $ok, 'off: pattern mismatch passes' );
}

#### no constraint present = nothing to check ##########################
$Amazon::API::VALIDATE_MODE = 'strict';
( $ok, $err ) = mk( type => 'string', _value => 'anything goes' );
ok( $ok, 'no enum/min/max/pattern = unconstrained value constructs' );

done_testing;
