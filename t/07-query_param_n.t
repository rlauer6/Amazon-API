use Test::More;
use Amazon::API::Botocore::Shape::Utils qw(query_param_n);

# empty string is now EMITTED as key=
is_deeply( [ query_param_n( { Path => q{} }, undef ) ], ['Path='], 'empty string leaf serializes as key= (present-but-empty)' );

# undef is still DROPPED (member not provided)
is_deeply( [ query_param_n( { Path => undef }, undef ) ], [], 'undef leaf is omitted' );

# the actual case you care about: nested struct -> list -> string
is_deeply(
  [ sort( query_param_n( { PathPatternConfig => { RegexValues => ['^/builder/.*$'] } }, 'Conditions.member.1' ) ) ],
  ['Conditions.member.1.PathPatternConfig.RegexValues.member.1=^/builder/.*$'],
  'regex leaf flattens to the correct member path'
);

done_testing;
