use strict;
use warnings;

use Amazon::API::Botocore::Shape::Utils qw(register_service_shapes);
use Amazon::API;
use Data::Dumper;
use English qw(-no_match_vars);
use HTTP::Response;
use JSON qw(decode_json);
use Log::Log4perl::Level;
use Log::Log4perl;
use Test::More;
use Scalar::Util qw(blessed);

{

  package Amazon::API::ProtocolTest;

  use parent qw(Amazon::API);
}

Log::Log4perl->easy_init(
  { level  => $ENV{DEBUG} ? $DEBUG : $INFO,
    layout => '%F{1}-%L-%M: %m%n',
  }
);

my $corpus = load_corpus('output/rest-json.json');

my $case_id = $ENV{CASE_ID};

foreach my $suite ( @{$corpus} ) {
  register_service_shapes( ProtocolTest => $suite->{shapes}, );

  foreach my $case ( @{ $suite->{cases} // [] } ) {
    next
      if $case_id
      && $case->{id} ne $case_id;

    my $response = $case->{response} // {};

    next
      if ( $response->{status_code} // 200 ) < 400;

    subtest $case->{id} => sub {
      my $api = Amazon::API::ProtocolTest->new(
        service           => 'protocol-test',
        version           => $suite->{metadata}->{apiVersion},
        botocore_metadata => $suite->{metadata},
        botocore_shapes   => $suite->{shapes},
        logger            => Log::Log4perl->get_logger,
        log_level         => $ENV{DEBUG} ? 'debug' : 'error',

      );

      #
      # Build the same fake HTTP response object that output-query.t
      # currently passes into decode_response().
      #
      my $http_response = create_response($case);

      my $error;

      eval { $api->_check_response($http_response); };

      $error = $EVAL_ERROR;

      isa_ok( $error, 'Amazon::API::Error', );

      if ( ref $error && $error->isa('Amazon::API::Error') ) {
        is( $error->get_error, $response->{status_code}, 'HTTP status matches Botocore fixture', );
      }
      else {
        diag(
          Dumper(
            [ case              => $case->{id},
              botocore_response => $response,
              exception         => $error,
            ]
          )
        );
      }
    }
  }
}

done_testing();

use HTTP::Response;

########################################################################
sub create_response {
########################################################################
  my ($case) = @_;

  my $response = $case->{response};

  my $http_response = HTTP::Response->new( $response->{status_code}, );

  foreach my $header ( keys %{ $response->{headers} // {} } ) {
    $http_response->header( $header => $response->{headers}->{$header}, );
  }

  $http_response->content( $response->{body} // q{}, );

  return $http_response;
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
