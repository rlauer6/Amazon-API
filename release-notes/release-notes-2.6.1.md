# Release Notes — Amazon::API v2.6.1

## Overview

Version 2.6.1 is a significant correctness release focused on
achieving alignment with the Botocore protocol test corpus. This
release introduces a new embedded XML parser
(`Amazon::API::XML::Simple`), a new timestamp parsing utility,
comprehensive multi-protocol serialization fixes, and an expanded test
suite covering five of the six Botocore wire protocols.

---

## New Features

### `Amazon::API::XML::Simple` — Embedded XML Parser

A new internal XML::Simple-compatible parser
(`Amazon::API::XML::Simple`) replaces the upstream `XML::Simple`
dependency throughout the codebase. This embedded parser correctly
preserves whitespace-only character data when `NormaliseSpace` is
disabled — a behaviour that upstream XML::Simple 2.25 does not
support. Both `Amazon::API` and `Amazon::API::Error` now use this
parser for consistency.

### `parse_timestamp` Utility Function

A new `parse_timestamp` function has been added to
`Amazon::API::Botocore::Shape::Utils` and exported for use across the
stack. It handles:

- Unix epoch integers and floats
- ISO 8601 timestamps with timezone offsets (`2015-06-17T22:11:58Z`,
  `+HH:MM`)
- RFC 822 / HTTP date strings (`Wed, 17 Jun 2015 22:11:58 GMT`)

This replaces ad-hoc inline timestamp parsing previously scattered
across `Serializer.pm`.

### Botocore Corpus Test Suite

A comprehensive corpus test suite has been added covering five of the
six Botocore wire protocols:

- `ec2`, `json`, `query`, `rest-json`, `rest-xml`
- Input serialization tests for each protocol
- Output deserialization tests for each protocol
- Error response tests for each protocol

---

## Dependency Changes

### Added

| Module | Minimum Version | Notes |
|---|---|---|
| `Data::UUID` | 1.227 | Auto-generates `idempotencyToken` fields |
| `URI::Escape` | 5.36 | Replaces `URL::Encode` for query-string encoding |
| `XML::SAX` | 1.02 | Backend for `Amazon::API::XML::Simple` |
| `XML::NamespaceSupport` | 1.12 | Backend for `Amazon::API::XML::Simple` |

### Removed

| Module | Notes |
|---|---|
| `XML::Simple` | Replaced by embedded `Amazon::API::XML::Simple` |

### Suggested (Optional)

| Module | Minimum Version | Notes |
|---|---|---|
| `XML::Parser` | 2.47 | Faster SAX backend for `Amazon::API::XML::Simple` |

### Test Dependencies Added

| Module | Minimum Version |
|---|---|
| `JSON::PP` | 4.16 |

---

## Bug Fixes and Improvements

### `Amazon::API` (Core)

- **`choose`**: Refactored to correctly propagate list, scalar, or
  void context into the code block.
- **`decode_response`**: Extensive fixes for Botocore corpus test
  alignment across all protocols:
  - JSON protocols now return `{}` when there is no output shape or no
    response body.
  - `rest-json` payload responses are now correctly wrapped before
    serialization.
  - `rest-xml`, `ec2`, and `query` empty-output responses are now
    handled correctly.
  - `rest-xml` payload member root-name unwrapping is now correct.
  - Header (`location: header`) and header-map (`location: headers`)
    output members are now fully deserialized, including list types,
    boolean coercion, and timestamp parsing.
  - `statusCode`-located output members are now extracted from the
    HTTP response code.
- **`is_param_type`**: Fixed to return the member name (not empty
  string) when no `locationName` is present at the requested location.
- **`init_botocore_request`**: Operations with no input shape now
  return the correct empty value per protocol:
  - `query` / `ec2`: returns `[]`
  - `rest-json`: returns `undef`
  - All others: returns `{}`
  - `headers`-located request members (map-type) are now correctly
    extracted and sent as HTTP headers.
- **`_resolve_request_content`**: Comprehensive protocol-specific
  fixes for `rest-json` and `rest-xml` payload handling, including
  correct empty-body detection, `xmlNamespace` attribute injection,
  and union type support.
- **`serialize_content`**: Added correct handling for `ec2` protocol
  (previously only `query` was handled). Added a dedicated `rest-json`
  path with payload-aware body encoding.
- **`create_urlencoded_content`**:
  - Fixed `split` to use limit of 2 to correctly handle values
    containing `=`.
  - Switched from `url_encode` (`URL::Encode`) to `uri_escape_utf8`
    (`URI::Escape`) — values are now correctly percent-encoded as
    UTF-8.
  - `undef`-valued pairs are now filtered out rather than emitting a
    bare `=`.
- **`_to_xml`**: Fixed attribute and `_text` node handling; `_attr`
  hash is no longer mutated before child iteration.

### `Amazon::API::Botocore::Shape`

- Added `document` and `xmlNamespace` accessors.
- **`_init_structure`**: Automatically generates a UUID for members
  marked `idempotencyToken` when not supplied by the caller (requires
  `Data::UUID`).
- **`_init_value`**: Raw value is stored directly for `document`-typed
  shapes; `float` is now a recognised scalar type.
- **`get_shape_type`**: Returns `SCALAR` for `document`-typed shapes.
- **`finalize`**: Handles `NaN`, `Infinity`, and `-Infinity` for
  float/double types. Boolean serialization now emits string
  `'true'`/`'false'` for `ec2`, `query`, and `rest-xml` protocols, and
  `JSON::PP::true`/`JSON::PP::false` for JSON protocols.
- **`finalize_map`**: Major protocol-specific rewrite:
  - `query`/`ec2`: entries are indexed as `entry.N`.
  - `rest-xml`: entries are serialized as `{ entry => [...] }` with
    `key`/`value` sub-elements, respecting `xmlNamespace`.
  - JSON protocols: returns a plain hash when no key/value location
    names are defined.
- **`finalize_list`**: Major protocol-specific rewrite:
  - `ec2`: returns a numeric-indexed hash.
  - `query`: returns a `member.N`-indexed hash.
  - `rest-xml`: returns `{ $member_name => \@list }`.
  - Timestamp formatting is now applied per-element for `rest-xml` lists.
- **`finalize_structure`**: Major protocol-specific rewrite:
  - `ec2`: applies `queryName` and `ucfirst` `locationName` conventions.
  - `rest-xml`: emits `_attr` entries for `xmlAttribute` members;
    injects `xmlNamespace` attributes.
  - JSON protocols: skips members with a defined but `undef` inner value.
  - Flattened list and map members are unwrapped correctly for
    `query`/`ec2` and `rest-xml`.
  - Blob payload members in `rest-xml`/`rest-json` are passed through
    raw (not base64-encoded).
- Added helper functions `_xml_namespace_attributes`,
  `_apply_local_xml_namespace`, and `_apply_xml_namespace`.

### `Amazon::API::Botocore::Shape::Serializer`

- **`_serialize_structure`**: Skips members with `undef` values under
  JSON protocols; passes `payload` and `flattened` flags through to
  nested `serialize` calls.
- **`_serialize_list`**: Fixed list extraction to handle non-hash
  `$data` arguments correctly.
- **`serialize`**:
  - Accepts two new keyword arguments: `payload` and `flattened`.
  - `document`-typed shapes return data directly.
  - `rest-xml` root-name unwrapping is now applied before type dispatch.
  - Added `float` and `double` type handlers (with `NaN`/`Infinity`
    passthrough).
  - `boolean`: response deserialization now always returns
    `JSON::true`/`JSON::false`.
  - `blob`: returns `$EMPTY` when the blob shape exists but the value
    is `undef`; passes raw data through for streaming or payload
    blobs.
  - `timestamp`: delegates to the new `parse_timestamp` utility.
  - `map`: added correct handling for `query`/`ec2`/`rest-xml`
    entry-format maps, including empty-map detection.

### `Amazon::API::Botocore::Shape::Utils`

- **`query_param_n`**: Now correctly serializes `JSON::PP` boolean
  values as the strings `'true'` and `'false'`.

### `Amazon::API::Error`

- Replaced `XML::Simple` with `Amazon::API::XML::Simple` for
  consistency with the rest of the stack.

---

## Test Suite

- **`t/01-urlencode.t`**: Added a test asserting correct UTF-8
  percent-encoding of Unicode characters in query-string values
  (e.g. emoji `U+1F639` → `%F0%9F%98%B9`). Converted to
  `done_testing`.
- **`t/07-query_param_n.t`**: Reorganised into subtests; added tests
  for `JSON::PP::true` and `JSON::PP::false` serialization.
