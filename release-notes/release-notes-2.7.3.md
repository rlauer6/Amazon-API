# Amazon::API 2.7.3 Release Notes

**Release Date:** 2026-09-03
**Distribution:** Amazon-API
**Author:** Rob Lauer <rclauer@gmail.com>

---

## Overview

This is a security-focused maintenance release that hardens diagnostic
logging and prevents AWS authentication material from appearing in log
output. API request and response behavior is otherwise unchanged.

---

## Changes

### Security

#### Sensitive Data Redacted from Logs

Log output across several methods has been hardened to prevent AWS
authentication material from appearing in diagnostic logs.

The following HTTP headers are now automatically redacted, replaced
with `[REDACTED]`, wherever they appear in log output:

- `Authorization`
- `X-Amz-Security-Token`

Affected methods and their changes:

- **`get_valid_token`** — The session token value is no longer dumped
  to the trace log. A generic `"valid session token present"` message
  is emitted instead.
- **`submit`** — The raw `%options` hash (which may contain headers
  carrying credentials) is now sanitized before being logged. The
  headers array in the request trace log is likewise sanitized.
- **`submit`** (signed request) — The `HTTP::Request` object, which
  contains the signed `Authorization` header, is sanitized before
  being passed to the trace logger.
- **`_set_request_content`** — The `HTTP::Request` object is sanitized
  before being logged at the trace level.

#### Removal of generic `DEBUG` environment logging control

Generic `DEBUG` environment handling has been removed. `Amazon::API` no
longer enables diagnostic logging merely because an unrelated `DEBUG`
environment variable is present. Logging must now be enabled
explicitly through `Amazon::API` configuration.

Setting a `DEBUG` environment variable would cause `Amazon::API` to
enable diagnostic logging, potentially exposing sensitive application
data.


#### Potentially sensitive diagnostics moved to TRACE

Diagnostic logging that may contain API request parameters, response
payloads, serialized values, pagination data, request bodies, or other
application data has been moved from DEBUG to TRACE. DEBUG logging is
intended for operational diagnostics that do not expose application
payloads.

### New

#### `_sanitize` Method

A new private method, `_sanitize`, has been added to `Amazon::API`. It
performs deep, recursive sanitization of values before they are passed
to the logger.

It handles the following data types:

- **`HTTP::Request` objects** — Clones the request and redacts
  sensitive headers in the clone.
- **Hash references** — Recursively copies the hash, replacing values
  for sensitive HTTP header names with `[REDACTED]`.
- **Array references** — Recursively copies the array. When a
  sensitive header name appears as a bare string element (as in a flat
  header list), the immediately following value element is also
  redacted.
- **Scalars and all other values** — Passed through unchanged.

### Minor

- **`_unpack_args`** — A debug `Dumper` log call that logged raw
  method arguments has been removed.
- **`_to_xml`** — Internal whitespace and formatting tidied; no
  behavioural change.

### Logging

The default log level is `info`. It may be changed at construction time
with `log_level` or later with `set_log_level()`.

---

## Upgrading

This release is otherwise a drop-in replacement for
2.7.2. Applications that relied on the generic `DEBUG` environment variable
to enable diagnostic logging must now set `log_level` explicitly.

