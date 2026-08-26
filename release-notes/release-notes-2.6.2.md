# Release Notes — Amazon::API v2.6.2

**Released:** Wed Aug 26 2026  
**Distribution:** Amazon-API  
**Author:** Rob Lauer \<rclauer@gmail.com\>

---

## Overview

Version 2.6.2 is a maintenance release focused on a correctness fix in
response decoding for REST protocols and a significant refactoring of the
Botocore corpus test suite to eliminate duplicated test code.

---

## Bug Fixes

### `Amazon::API` — `decode_response` payload shape handling

The `decode_response` method now correctly honours top-level **output
payload shapes** before attempting content-based response decoding.

Previously, when a `rest-json` or `rest-xml` operation declared a
`payload` member whose shape type was `blob` or `string`, the response
body was still passed through the JSON/XML decoder, corrupting raw
binary or plain-text payloads. The fix inspects the output shape's
`payload` trait early in `decode_response` and, when the resolved
payload type is `blob` or `string`, skips content decoding entirely and
delivers the raw response body directly to the downstream serializer.

```
lib/Amazon/API.pm.in (decode_response)
  - Resolve output payload shape and type before content-type-based decoding
  - Skip JSON/XML decoding when payload type is 'blob' or 'string'
  - Relocated output / output_shape derivation to earlier in the method
```

---

## Test Suite Refactoring

The Botocore protocol corpus tests have been substantially restructured
to remove per-protocol duplication.

### Input tests — renamed

All input serialisation test files have been renamed with an `input-`
prefix to make the distinction between input and output tests explicit
at a glance:

| Old name | New name |
|---|---|
| `corpus-test/t/ec2.t` | `corpus-test/t/input-ec2.t` |
| `corpus-test/t/json.t` | `corpus-test/t/input-json.t` |
| `corpus-test/t/query.t` | `corpus-test/t/input-query.t` |
| `corpus-test/t/rest-json.t` | `corpus-test/t/input-rest-json.t` |
| `corpus-test/t/rest-xml.t` | `corpus-test/t/input-rest-xml.t` |

### Shared driver scripts — new

Repeated boilerplate that previously existed in every per-protocol
`.t` file has been extracted into shared driver scripts. The `.t` files
are now symbolic links to these drivers; the corpus file to exercise is
determined at runtime from the link name.

| New file | Purpose |
|---|---|
| `corpus-test/t/input-test.pl` | Shared driver for all input serialisation tests |
| `corpus-test/t/input-query.pl` | Query-protocol-specific input helpers |
| `corpus-test/t/input-rest-xml.pl` | REST-XML-specific input helpers |
| `corpus-test/t/input-ec2.pl` | EC2-protocol-specific input helpers |
| `corpus-test/t/output-test.pl` | Shared driver for all output deserialisation tests |

### Output tests — converted to symlinks

All output test files (`output-ec2.t`, `output-json.t`,
`output-query.t`, `output-rest-json.t`, `output-rest-xml.t`) are now
symbolic links pointing to the single `output-test.pl` driver, removing
several hundred lines of duplicated test scaffolding.

### Shared library — new

```
corpus-test/lib/ProtocolTest.pm
```

Common helper code used by multiple corpus test drivers has been
extracted into a dedicated library module.

---

## Build / Repository Changes

### `.gitignore` — scope of Perl file exclusions narrowed

The previous blanket rules:

```
**/*.pl
**/*.pm
```

have been removed. These rules were accidentally excluding generated
`.pl` and `.pm` files that are legitimately part of the repository
(including the new corpus-test driver scripts and library). Exclusions
that remain in place target only the specific generated artefacts that
should not be tracked.

---

## Upgrade Notes

This release is backwards-compatible. No public API, dependency, or
configuration changes have been made beyond the `decode_response` fix.
Callers that rely on `rest-json` or `rest-xml` operations with `blob`
or `string` payload shapes should verify that their responses are now
decoded correctly.