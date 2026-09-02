# Release Notes — Amazon::API v2.7.2

**Released:** Wed Sep 2 2026  
**Author:** Rob Lauer \<rclauer@gmail.com\>

---

## Overview

Version 2.7.2 is a maintenance release that adds Botocore version and
commit metadata to generated service stubs, improves the stub
generation pipeline, updates POD documentation throughout, and makes
several build infrastructure corrections.

---

## What's New

### Botocore Version Metadata in Generated Stubs

Generated service stub modules (produced by `amzn-api` via
`Amazon::API::Role::Botocore`) now record the Botocore version and
commit hash used at generation time.

- `Amazon::API::Role::Botocore` (`create_stub`) now reads
  `botocore_version` and `botocore_commit` from
  `Amazon::API::BuildInfo` and passes them through the stub template
  pipeline.
- The stub template (`share/stub.pm.tmpl`) now sets two package-level
  variables in every generated service class:

```perl
our $VERSION = '@botocore_version@';
our $COMMIT  = '@botocore_commit@';
```

Previously `$VERSION` was set to the Botocore service API date
string. It now reflects the Botocore release version, and the new
`$COMMIT` variable records the exact commit, providing a precise and
auditable provenance record in every generated module.

- The `version` template variable has been replaced by
  `botocore_version` and `botocore_commit` in the stub template
  variable list.

---

## Documentation Updates (`lib/Amazon/API.pm.in`)

The main module POD has been significantly revised for clarity and
accuracy:

- **Introduction** — Reworded to clarify the DIY design philosophy and
  the role of `Amazon::API::Help` for service documentation.
- **Response Serialization** — Rewritten to describe the current
  serialization behaviour accurately. The new text removes outdated
  caveats and clearly documents when raw responses are returned and
  how to make serialization failures fatal via
  `raise_serialization_errors`.
- **Protocol Compatibility Testing** — New section documenting that
  request/response serialization is tested against Botocore's own
  protocol test fixtures (632 request/response cases + 31 error cases
  across `query`, `ec2`, `json`, `rest-json`, and `rest-xml`
  protocols). Explains the scope and limits of protocol corpus
  coverage.
- **Does this work for all AWS APIs?** — Substantially
  updated. Replaced anecdotal wording with a clear description of
  automated Botocore protocol coverage, what that coverage does and
  does not guarantee, and guidance on S3 and unsupported protocols
  (`smithy-rpc-v2-cbor`).
- **Troubleshooting FAQ** — Reworked "I tried XYZ service and it
  didn't work" answer. Consolidated into a concise, actionable guide:
  enable debugging, compare with `aws --debug`, use `decode_always`,
  and report service-specific exceptions.
- **Why aren't all AWS services on CPAN?** — New FAQ entry explaining
  the DarkPAN model (`https://cpan.openbedrock.net/orepan2`) for
  generated service distributions and why publishing hundreds of
  generated modules to CPAN is not the design goal.
- **I downloaded Amazon::API::SQS but there's no documentation** — New
  FAQ entry pointing to `Amazon::API::Help`.
- **XML::Simple note** — New inline note explaining that `Amazon::API`
  uses a vendored, locally maintained fork of `XML::Simple` to work
  around upstream bugs (specifically, the upstream version ignoring
  `NormaliseSpace`).
- **Minor typo fixes** — `willng` → `willing`, `lean as` → `as lean
  as`, version reference updated from 2.6.0 to 2.7.1 in stability FAQ.

---

## Build Infrastructure

### `Makefile`

- `PACKAGE_VERSION` is now exported alongside `MODULE_NAME` so both
  are available to sub-processes and template resolution steps.
- The `$(MODULE_PATH).in` recipe now runs `gen-vars-file` **before**
  the template resolution step (previously the order was reversed,
  which could cause the vars file to be missing when first needed).
- A new `extra-files` phony target ensures the `extra-files` file
  exists before `extra-files.mk` is generated, eliminating a potential
  race condition on clean builds.
- `extra-files.mk` now depends on `| extra-files` (order-only prerequisite).

### `builder`

- Fixed a bug where `CPAN::Maker::Bootstrapper` was written to
  `build-requires` with `>` (overwrite) instead of `>>` (append),
  which would silently discard any existing `build-requires` entries.

### `deps.mk`

- Removed a stale duplicate dependency block for `./API.pm` (an
  artefact of an old build layout).
- Added `./lib/Amazon/API/BuildInfo.pm` as a dependency of
  `./lib/Amazon/API/Role/Botocore.pm`, reflecting the new `use
  Amazon::API::BuildInfo` import.
- Minor whitespace cleanup.

### `.gitignore`

- Added `**/*.pl` and `**/*.pm` to ignore generated Perl source files
  project-wide.

---

## Dependency Changes

| Module | Change |
|---|---|
| `Amazon::API::BuildInfo` | Now a runtime dependency of `Amazon::API::Role::Botocore` |
| `CLI::Simple::Utils` | `slurp_json` added to imports in `Role::Botocore` |

---

## Upgrade Notes

- Generated service stubs will need to be **regenerated** with
  `amzn-api` to pick up the new `$VERSION` and `$COMMIT`
  variables. Existing stubs will continue to function but will not
  carry Botocore provenance metadata.
- No changes to the public `Amazon::API` runtime API. Existing callers
  require no modifications.
