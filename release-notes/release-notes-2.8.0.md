# Release Notes — Amazon::API 2.8.0

**Released:** 2026-09-06  
**Author:** Rob Lauer \<rclauer@gmail.com\>

---

## Overview

Version 2.8.0 is a significant feature release introducing
comprehensive support for Botocore endpoint rule-set resolution for
SigV4 services. This enables dynamic, per-request endpoint resolution
including support for FIPS endpoints, dual-stack, global endpoints,
force-path-style, and service-specific client context parameters. A
new **ServiceHook** mechanism allows per-service (and per-operation)
customization of request building. SigV4 signing now honours
endpoint-derived auth scheme overrides, including
`disableDoubleEncoding` for services such as S3 Outposts.

---

## New Features

### Endpoint Rule Set Support

- **`Amazon::API::EndpointResolver`** — new module that evaluates
  Botocore `endpoint-rule-set-1.json` rule sets to resolve the correct
  service endpoint URL at request time.
- **`Amazon::API::EndpointContext::Compiler`** — new module that
  pre-compiles `operationContextParams` expressions from Botocore
  operation definitions into an efficient runtime form, stored in the
  stub metadata.
- Endpoint resolution now considers all standard Botocore endpoint
  context parameter sources:
  - **`clientContextParams`** — caller-supplied, service-declared
  per-client parameters (e.g. `UseArnRegion`).
  - **`contextParam`** — request members bound directly to endpoint
  context parameters.
  - **`operationContextParams`** — compiled JMESPath expressions
  evaluated against the live request object.
  - **`staticContextParams`** — per-operation static values baked into
    the Botocore operation definition.
- Endpoint context values follow Botocore precedence, from highest to
  lowest: `staticContextParams`, `contextParam`,
  `operationContextParams`, `clientContextParams`, SDK built-ins,
  and rule-set defaults.
- New accessors on `Amazon::API`:
  - `endpoint_rule_set` — the deserialized rule set loaded from stub
    metadata.
  - `resolved_endpoint` — the endpoint object returned by the resolver
    (carries `url` and `properties` including `authSchemes`).
  - `compiled_endpoint_context` — pre-compiled operation context expressions.
  - `botocore_client_context_params` — the service's declared client
    context parameter schema.
  - `client_context_params` — caller-supplied values; validated
    against the schema at construction time.
  - `use_fips`, `use_dualstack`, `use_global_endpoint`,
    `use_force_path_style` — standard AWS endpoint modifier flags.

### ServiceHook Role

- **`Amazon::API::ServiceHook`** — new `Role::Tiny` role providing
  default (no-op) implementations of service hook methods.
- **`Amazon::API::S3/ServiceHook`** — S3-specific service hook
  implementation.
- Generated stubs now compose in either a service-specific
  `<Package>::ServiceHook` (if present) or the default
  `Amazon::API::ServiceHook` role via a `BEGIN`-time `with` call.
- The hook method `_service_hook_before_parameter_build($request,
  \%http)` is called just before URI parameter substitution, allowing
  per-service mutation of the operation's `requestUri` template
  (e.g. S3's bucket-addressing rewrite).

### Auth Scheme Selection from Resolved Endpoint

- `submit()` now calls `_get_auth_scheme()` to derive signing
  parameters from the resolved endpoint's `properties.authSchemes`
  array rather than always using the service name and region directly.
- `signingName`, `signingRegion`, and `disableDoubleEncoding` are all honoured when present in the endpoint metadata.

### `disable_double_encoding` in SigV4

- `Amazon::API::Signature4` now passes `disable_double_encoding`
  through to `Amazon::Signature4::Lite` (requires
  `Amazon::Signature4::Lite` ≥ 1.0.5).
- Required for correct signing of S3-family services that pre-encode
  path segments.

### `partitions.json` Bundled

- `partitions.json` from the Botocore checkout is now copied into the
  build and included in the distribution's `share/` directory,
  enabling the endpoint resolver to evaluate partition-based rules
  without a live Botocore checkout.

### Client Context Parameter Validation

- `new()` calls `_validate_client_context_params()` at construction
  time and croaks on any unknown parameter name (i.e. a name not
  declared in the service's `clientContextParams` schema).

---

## Improvements

### URI Encoding in `init_botocore_request`

- Greedy URI template variables (`{Var+}`) are now correctly encoded
  using `uri_escape_utf8` with a permissive character class that
  preserves `/`, `~`, `-`, `.`, and `_`, matching the AWS SDKs'
  behaviour.
- Standard (`{Var}`) template variables are fully percent-encoded via
  `uri_escape_utf8`.
- Template variable matching now uses `\Q...\E` quoting to correctly
  handle variable names containing regex metacharacters.

### Serializer Fixes (`Amazon::API::Botocore::Shape::Serializer`)

- **`_serialize_list`**: guarded against an uninitialized-value
  warning when testing list elements for `reftype`.
- **`serialize`**: the root-element unwrapping logic for `rest-xml`
  and `query`/`ec2` protocols was rewritten to be more correct and to
  handle the case where S3 (and similar services) return a single-key
  response whose key does not match any modeled `locationName`.  The
  new logic:
  1. Prefers an exact shape-name match.
  2. Falls back to `locationName` match.
  3. For single-key responses, checks whether the key corresponds to a
     modeled member before unwrapping, avoiding false unwraps on real
     payload keys.

### Botocore Role (`Amazon::API::Role::Botocore`)

- `get_service_descriptions()` now loads and returns
  `endpoint-rule-set-1.json` and its SHA-256 digest alongside the
  existing service-2 and paginators metadata.
- `create_stub()` now compiles and stores `compiled_endpoint_context`,
  `client_context_params`, `endpoint_rule_set`, and
  `endpoint_rule_set_1_digest` in the stub's serialized metadata
  (`.api.gz`).
- `fetch_boto_services()` calculates and records the
  `endpoint_rule_set_1_digest` for each service.
- New method `fetch_endpoint_rule_set` (alias for `fetch_json_file`).

### Provenance Records

- `endpoint-rule-set-1.json` digest is now included in the signed
  provenance record produced by
  `Amazon::API::Provenance::Role::Records`.

### Stub Template

- Stubs compose in `Amazon::API::ServiceHook` (or a service-specific
  override) at `BEGIN` time.
- `new()` now passes `botocore_client_context_params`,
  `compiled_endpoint_context`, and `endpoint_rule_set` to
  `SUPER::new()`.

---

## Dependency Changes

| Dependency | Previous | Now |
|---|---|---|
| `Amazon::Signature4::Lite` | 1.0.2 | **1.0.5** |
| `CLI::Simple::Utils` | — | **2.2.2** (new) |
| `Role::Tiny::With` | — | **2.002004** (new) |

---

## New Modules

| Module | Description |
|---|---|
| `Amazon::API::EndpointResolver` | Evaluates Botocore endpoint rule sets |
| `Amazon::API::EndpointContext::Compiler` | Compiles `operationContextParams` JMESPath expressions |
| `Amazon::API::ServiceHook` | Default (no-op) service hook role |
| `Amazon::API::S3::ServiceHook` | S3-specific service hook implementation |

---

## New Tests

| Test file | Coverage |
|---|---|
| `t/13-endpoint-resolver.t` through `t/22-endpoint-resolver.t` | Endpoint rule set resolution scenarios |
| `t/20-endpoint-compiler.t` | `EndpointContext::Compiler` compilation and evaluation |
| `t/23-uri-greedy-encoding.t` | Greedy (`{Var+}`) vs standard (`{Var}`) URI template encoding |

### Updated Tests

- `t/04-rest-xml-payload.t`, `t/05-rest-xml-nonpayload.t`,
  `t/08-rest-xml-header.t` — now compose `Amazon::API::ServiceHook`
  into the test package.
- `t/06-signature4-adapter.t` — added test asserting
  `disable_double_encoding` is passed through to
  `Amazon::Signature4::Lite`.

---

## Bug Fixes

- Fixed a spurious warning in `_serialize_list` when list elements are
  `undef` or scalars (not references).
- Fixed incorrect root-element unwrapping in `serialize` for S3
  rest-xml responses that have no matching `locationName` on the
  top-level key.
- `_service_hook_before_parameter_build` stub added to
  `ProtocolTest.pm` so corpus tests no longer fail when the hook is
  called during request building.

---

## Upgrade Notes

- Stubs regenerated with this version of `Amazon-API` will include
  endpoint rule set data and ServiceHook composition. Stubs generated
  by earlier versions continue to work (missing fields are treated as
  `undef`/empty).
- If you supply `client_context_params` to a stub's `new()`, those
  parameter names are now validated against the service
  schema. Unknown names cause a `croak` at construction time.
- `Amazon::Signature4::Lite` must be upgraded to **1.0.5** or later.
- `Role::Tiny::With` is now a runtime dependency.
- Endpoint auth scheme selection in 2.8.0 supports SigV4.
  SigV4a and S3 Express authentication are not yet supported.
  
## Roadmap

| Version | Feature/Capability | Target Date | Status |
| ------- | ------------------ | ----------- | ------ | 
| 2.8.0 | Endpoint rules + auth -> signer integration | 9/6 | Released |
| 2.9.0 | SigV4a | 9/26 | - |
| 2.10.0 | S3 Express | 10/16 | - |
| 3.0.0 |  Smithy protocol work + handler audit/fixes. | 11/27 | - |

