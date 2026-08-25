#!/usr/bin/env perl

use strict;
use warnings;

use JSON::PP;
use Test::More;
use Amazon::API::Botocore::Shape::Utils qw(query_param_n);

########################################################################
subtest 'present-but-empty' => sub {
########################################################################
  # empty string is now EMITTED as key=
  is_deeply( [ query_param_n( { Path => q{} }, undef ) ],
    ['Path='], 'empty string leaf serializes as key= (present-but-empty)' );

  # undef is still DROPPED (member not provided)
  is_deeply( [ query_param_n( { Path => undef }, undef ) ], [], 'undef leaf is omitted' );

  # the actual case you care about: nested struct -> list -> string
  is_deeply(
    [ sort( query_param_n( { PathPatternConfig => { RegexValues => ['^/builder/.*$'] } }, 'Conditions.member.1' ) ) ],
    ['Conditions.member.1.PathPatternConfig.RegexValues.member.1=^/builder/.*$'],
    'regex leaf flattens to the correct member path'
  );
};

########################################################################
subtest 'JSON booleans' => sub {
########################################################################
  is( query_param_n( JSON::PP::true, 'Foo' ), 'Foo=true', 'serializes JSON true', );

  is( query_param_n( JSON::PP::false, 'Foo' ), 'Foo=false', 'serializes JSON false', );
};

done_testing;
