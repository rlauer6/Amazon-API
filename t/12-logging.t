#!/usr/bin/env perl

## Regression tests for Amazon::API diagnostic logging security.
##
## The invariant tested here is deliberately broader than the individual
## sanitization implementation: AWS authentication material must never appear
## in diagnostic output, including at TRACE level.

use strict;
use warnings;

use Test::More;

use Amazon::API;
use HTTP::Request;
use HTTP::Response;

{
  package Local::CaptureLogger;

  sub new {
    my ($class) = @_;
    return bless { messages => [] }, $class;
  }

  sub _capture {
    my ( $self, @messages ) = @_;

    foreach my $message (@messages) {
      $message = $message->()
        if ref $message eq 'CODE';

      push @{ $self->{messages} }, defined $message ? $message : q{};
    }

    return;
  }

  sub trace { my $self = shift; return $self->_capture(@_); }
  sub debug { my $self = shift; return $self->_capture(@_); }
  sub info  { my $self = shift; return $self->_capture(@_); }
  sub warn  { my $self = shift; return $self->_capture(@_); }
  sub error { my $self = shift; return $self->_capture(@_); }
  sub fatal { my $self = shift; return $self->_capture(@_); }
  sub level { return; }

  sub output {
    my ($self) = @_;
    return join q{\n}, @{ $self->{messages} };
  }
}

{
  package Local::Credentials;

  sub new { return bless {}, shift; }

  sub get_aws_access_key_id     { return 'DO-NOT-LOG-ACCESS-KEY'; }
  sub get_aws_secret_access_key { return 'DO-NOT-LOG-SECRET-KEY'; }
  sub get_token                 { return 'DO-NOT-LOG-SESSION-TOKEN'; }
  sub is_token_expired          { return 0; }
}

{
  package Local::UserAgent;

  sub new { return bless {}, shift; }

  sub request {
    my ( $self, $request ) = @_;

    return HTTP::Response->new( 200, 'OK', [], q{{}} );
  }
}

my $authorization = 'DO-NOT-LOG-AUTHORIZATION';
my $session_token = 'DO-NOT-LOG-SESSION-TOKEN';
my $access_key    = 'DO-NOT-LOG-ACCESS-KEY';
my $secret_key    = 'DO-NOT-LOG-SECRET-KEY';

sub new_api {
  my $logger = Local::CaptureLogger->new;

  my $api = Amazon::API->new(
    service     => 'events',
    credentials => Local::Credentials->new,
    user_agent  => Local::UserAgent->new,
    no_logger   => 1,
  );

  $api->set_logger($logger);
  $api->set_log_level('trace');

  return ( $api, $logger );
}

subtest '_sanitize redacts AWS authentication headers' => sub {
  my ( $api, $logger ) = new_api();

  my $hash = $api->_sanitize(
    { Authorization          => $authorization,
      'X-Amz-Security-Token' => $session_token,
      ordinary               => 'visible',
    }
  );

  is( $hash->{Authorization}, '[REDACTED]', 'Authorization hash value redacted' );
  is( $hash->{'X-Amz-Security-Token'}, '[REDACTED]', 'session-token hash value redacted' );
  is( $hash->{ordinary}, 'visible', 'ordinary hash value preserved' );

  my $array = $api->_sanitize(
    [ Authorization          => $authorization,
      'X-Amz-Security-Token' => $session_token,
      ordinary               => 'visible',
    ]
  );

  is_deeply(
    $array,
    [ Authorization          => '[REDACTED]',
      'X-Amz-Security-Token' => '[REDACTED]',
      ordinary               => 'visible',
    ],
    'flat header list redacted'
  );

  my $request = HTTP::Request->new(
    GET => 'https://example.invalid/',
    [ Authorization          => $authorization,
      'X-Amz-Security-Token' => $session_token,
    ]
  );

  my $sanitized_request = $api->_sanitize($request);

  is( $sanitized_request->header('Authorization'), '[REDACTED]', 'request Authorization redacted' );
  is( $sanitized_request->header('X-Amz-Security-Token'), '[REDACTED]', 'request session token redacted' );

  is( $request->header('Authorization'), $authorization, 'original request is not modified' );
};

subtest '_set_request_content never logs authentication headers' => sub {
  my ( $api, $logger ) = new_api();

  my $request = HTTP::Request->new(
    POST => 'https://example.invalid/',
    [ Authorization          => $authorization,
      'X-Amz-Security-Token' => $session_token,
    ]
  );

  $api->_set_request_content(
    request      => $request,
    content      => q{{"message":"application data may appear at trace"}},
    content_type => 'application/json',
  );

  my $log = $logger->output;

  unlike( $log, qr/\Q$authorization\E/x, '_set_request_content does not log Authorization value' );
  unlike( $log, qr/\Q$session_token\E/x, '_set_request_content does not log session token value' );
};

subtest 'get_valid_token never logs the token value' => sub {
  my ( $api, $logger ) = new_api();

  is( $api->get_valid_token, $session_token, 'session token returned to caller' );

  my $log = $logger->output;

  unlike( $log, qr/\Q$session_token\E/x, 'session token value not logged' );
  like( $log, qr/valid\ session\ token\ present/x, 'generic token-presence message logged' );
};

subtest 'submit never logs AWS authentication material' => sub {
  my ( $api, $logger ) = new_api();

  $api->set_url('https://events.us-east-1.amazonaws.com');
  $api->set_http_method('POST');
  $api->set_content_type('application/x-amz-json-1.1');

  my $response = $api->submit(
    content      => q{{}},
    content_type => 'application/x-amz-json-1.1',
    headers      => [
      Authorization          => $authorization,
      'X-Amz-Security-Token' => $session_token,
    ],
  );

  isa_ok( $response, 'HTTP::Response' );

  my $log = $logger->output;

  unlike( $log, qr/\Q$authorization\E/x, 'caller Authorization value not logged' );
  unlike( $log, qr/\Q$session_token\E/x, 'session token not logged' );
  unlike( $log, qr/\Q$access_key\E/x, 'AWS access key id not logged through signed request' );
  unlike( $log, qr/\Q$secret_key\E/x, 'AWS secret access key not logged' );
};

subtest 'generic DEBUG environment variable does not enable diagnostics' => sub {
  local $ENV{DEBUG} = 1;

  my $api = Amazon::API->new(
    service     => 'events',
    credentials => Local::Credentials->new,
    user_agent  => Local::UserAgent->new,
    no_logger   => 1,
  );

  is( $api->get_log_level, 'info', 'DEBUG environment variable does not change default log level' );
};

done_testing;
