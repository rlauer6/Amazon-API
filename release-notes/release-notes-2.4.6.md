# Release Notes — Amazon::API v2.4.6

**Released:** 2026-08-01  
**Author:** Rob Lauer <rclauer@gmail.com>

---

## Overview

Version 2.4.6 is a significant feature release delivering three major
improvements: **request-side value validation** against Botocore shape
constraints, **HTTP header parameter support** for REST APIs (both
sending and receiving), and **full blob and timestamp handling**
across all protocols. Seven new test files accompany this
release. Build tooling has also been substantially modernised via a
`CPAN::Maker::Bootstrapper` update.

---

## New Features

### Request Validation (`$Amazon::API::VALIDATE_MODE`)

Botocore shape definitions carry value constraints — `enum`
membership, string `min`/`max` length, numeric `min`/`max`, and
regular-expression `pattern`. These constraints are now enforced
**before** a request is serialised and sent, so a bad parameter value
is caught locally with a clear error message rather than surfacing as
an opaque `InvalidParameterValue` from AWS.

Validation is governed by the new package variable `$Amazon::API::VALIDATE_MODE`:

| Mode | Behaviour |
|------|-----------|
| `strict` (default) | Throws an exception naming the parameter, the value, and — for `enum` — the permitted list. |
| `warn` | Emits a warning and continues. |
| `off` | Skips constraint checking entirely. |

The mode can be set globally or localised to a single call:

```perl
# Global relaxation
$Amazon::API::VALIDATE_MODE = 'warn';

# Per-call relaxation
{
    local $Amazon::API::VALIDATE_MODE = 'off';
    $ec2->RunInstances( \%params );
}
```

New functions implementing this in `Amazon::API::Botocore::Shape::Utils`:

- `check_enum($value, $enum_arrayref)` — validates against an enumeration.
- `_check($ok, $message)` — central dispatcher that reads `$VALIDATE_MODE` and either croaks, carps, or returns.
- `check_pattern()` — now routes through `_check()`.

### HTTP Header Parameter Support

REST-XML and REST-JSON APIs that carry members in HTTP **request
headers** (e.g. CloudFront's `IfMatch` → `If-Match`) are now handled
correctly:

- **Sending** (`init_botocore_request`): header-located members are
  extracted from the shape parameter hash and stashed in a new
  `botocore_request_headers` accessor. They are applied to the
  `HTTP::Request` object in `submit()` *before* SigV4 signing so that
  they become part of the signed request. The stash is cleared after
  each call to prevent leakage.
- **Receiving** (`decode_response`): header-located output members
  (e.g. `ETag`) are lifted from the HTTP response headers and merged
  into the result hash so callers can access them by member name
  (e.g. `$result->{ETag}`). `statusCode`-located members are handled
  similarly.

A guard was also added to `generate_xml()` so that a request body with
more than one root element croaks immediately with a descriptive
message rather than producing malformed XML that AWS rejects opaquely.

### `_resolve_request_content` (new method)

The body-serialisation decision logic has been extracted from
`init_botocore_request` into the new private method
`_resolve_request_content`. This makes the logic unit-testable in
isolation (see `t/06-content-resolution.t`) and documents the
per-protocol rules clearly:

- **rest-xml, no payload**: shape-name is the root element; `xmlns` rides the root.
- **rest-xml, with payload**: payload member is the root.
- **rest-json**: body is the inner members.
- **json / query / ec2**: body is the flat parameter hash.
- **non-POST with no parameters**: no body (`undef`).

### Blob Handling

- **Sending** (`Amazon::API::Botocore::Shape::finalize`):
  non-streaming value blobs (KMS Plaintext, Kinesis Data, …) are now
  base64-encoded via `MIME::Base64` before transmission. Streaming
  blobs (S3 `PutObject` body) pass through untouched, identified by
  the new `streaming` shape accessor.
- **Receiving**
  (`Amazon::API::Botocore::Shape::Serializer::serialize`): incoming
  base64-encoded blobs are decoded via
  `MIME::Base64::decode_base64`. Streaming blobs pass through.

### Timestamp Handling

A new `_format_timestamp($value, $format)` function in
`Amazon::API::Botocore::Shape` converts epoch seconds (or any object
implementing `->epoch`, such as `Time::Piece` or `DateTime`) to the
correct wire format:

| Format | Output |
|--------|--------|
| `unixTimestamp` | raw epoch number |
| `iso8601` | `2015-06-17T22:11:58Z` |
| `rfc822` | `Wed, 17 Jun 2015 22:11:58 GMT` |

Format resolution follows Botocore precedence: member
`timestampFormat` → shape `timestampFormat` → location default (header
→ `rfc822`, querystring → `iso8601`) → protocol default (JSON →
`unixTimestamp`, else `iso8601`).

New accessors added to `Amazon::API::Botocore::Shape`: `streaming`,
`timestampFormat`.

### JSON Body Correction (`serialize_content`)

JSON services require at least an empty object (`{}`) as a body; bare
empty strings caused `SerializationException`. The serialiser now
floors missing/empty parameters to `{}` for body-bearing methods. GET
requests with no parameters correctly produce no body (previously they
would emit a spurious `?{}` query string causing
`InvalidSignatureException`).

---

## API / HTTP Changes

### `Amazon::API::HTTP::Response`

- Added `headers()` — returns the full response headers hash (always
  lowercased, consistent with HTTP::Tiny's behaviour).
- Added `header($name)` — retrieves a single header by name, case-insensitively.

---

## Dependency Updates

| Package | Old | New |
|---------|-----|-----|
| `Amazon::Credentials` | 1.2.1 | 1.3.1 |
| `CLI::Simple` | 2.0.7 | 2.1.2 |
| `CLI::Simple::Constants` | 2.0.7 | 2.1.2 |
| `CLI::Simple::Utils` | 2.0.7 | 2.1.2 |
| `HTTP::Request` | 7.00 | 7.01 |
| `IO::Scalar` | 0 | 2.113 |
| `Pod::Find` | (unpinned) | 1.67 |
| `Term::ReadKey` | 0 | 2.38 |

New `suggests` tier added to `cpanfile`:

```
suggests "IO::Pager", "2.10";
suggests "Perl::Tidy", "20260204";
```

`Module::Load` removed from `Amazon::API::Error` in favor of `require XML::Simple`.

---

## New Tests

| File | Covers |
|------|--------|
| `t/05-rest-xml-nonpayload.t` | REST-XML requests without a payload member |
| `t/06-content-resolution.t` | `_resolve_request_content` in isolation |
| `t/07-get-empty-body.t` | GET requests produce no body |
| `t/08-rest-xml-header.t` | Header-located request parameters |
| `t/09-blob-and-statuscode.t` | Blob encoding/decoding; statusCode members |
| `t/10-timestamp.t` | `_format_timestamp` for all three formats |
| `t/11-value-validation.t` | `check_enum`, `check_pattern`, `_check` modes |

---

## Build / Tooling Changes

All managed build files have been updated by `CPAN::Maker::Bootstrapper`:

- **`perl.mk`**: `podchecker` now runs as part of syntax checking for
  both `.pm` and `.pl` files. Syntax checking and templating are
  combined back into the `%.pm` / `%.pl` pattern rules (the former
  `.checked` sentinel approach is retired). `check-syntax` becomes a
  phony convenience alias. `PERLCRITIC_SEVERITY` (default `5`) and
  `PERLCRITIC_THEME` (default `pbp`) are now configurable. `deps.mk`
  now depends on `.pm.in`/`.pl.in` source files rather than built
  artifacts, eliminating a chicken-and-egg rebuild during `make
  clean`.
- **`Makefile`**: `cpanfile` generation is split into three
  intermediate targets (`cpanfile.requires`, `cpanfile.recommends`,
  `cpanfile.suggests`). Dependency scanning produces `requires.raw`,
  `recommends.raw`, and `suggests.raw` in a single pass via
  `scandeps-static`. The `cmb filter` command is now used for
  skip/pin/preserve reconciliation. `update-available` is added to the
  default `DEPS` list. `CMB_UPDATE_CHECK` and `CMB_VERSION_DRIFT`
  variables control bootstrapper drift checking.
- **`update.mk`**: Version drift checking (`CMB_VERSION_DRIFT`) can be
  set to `fail` (default), `warn`, or `ignore`. CPAN update check is
  gated on `CMB_UPDATE_CHECK=on`. `.gitignore` is automatically
  updated during `make post-update`.
- **`git.mk`**: `NO_COMMIT=1` suppresses the initial commit. `git init` output is silenced.
- **`release-notes.mk`**: Uses `cmb release-notes` instead of `bootstrapper release-notes`.
- **`project.mk`**: New `install` target (`cpanm -n -v -l $(HOME) <tarball>`).
- **`builder`**: Docker local run instructions updated;
  `--no-prebuilt` added to default `cpm` installer flags;
  `CMB_VERSION_DRIFT=ignore` set for CI builds.
- **`.gitignore`**: `**/*.checked`, `**/*.pl`, `**/*.pm`, `**/*.raw` added.
- **`deps.mk`**: New file providing inter-module dependency edges for correct parallel build ordering.

---

## Documentation

`Amazon::API` POD has been updated with:

- A new **Request Validation** section explaining `$VALIDATE_MODE`,
  its three modes, and how to localise it per-call.
- An expanded **LIMITATIONS** section noting that validation is
  against a point-in-time Botocore snapshot.
- A new FAQ entry: *"How do I stop the client from rejecting a parameter value?"*
