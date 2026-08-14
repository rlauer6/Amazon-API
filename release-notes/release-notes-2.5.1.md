# Release Notes — Amazon-API v2.5.1

**Release Date:** 2026-08-13
**Author:** Rob Lauer

---

## Overview

Version 2.5.1 is a refactoring release focused on improving the
modularity and maintainability of the provenance subsystem. The core
provenance record operations have been extracted into a dedicated
role, and error handling in the Botocore stub renderer has been
hardened.

These changes are the foundation for the public signature site at
`https://cpan.openbedrock.net/signature/`. The records written and
signed by `Amazon::API::Provenance::Role::Records` are exactly what
the factory autobuilder publishes and what that site displays,
indexes, and verifies. Pulling the logic into a composable role is
what lets the factory's Lambda handler produce signed provenance on
demand without depending on the full `Amazon::API::Provenance` command
surface.

---

## What's New

### New Module: `Amazon::API::Provenance::Role::Records`

A new role (`lib/Amazon/API/Provenance/Role/Records.pm`) has been
introduced to encapsulate provenance record management logic that was
previously embedded directly in `Amazon::API::Provenance`. The
following methods have been moved into this role:

- `_verify_provenance`
- `_write_provenance_records`
- `_sign_provenance_records`
- `_create_tarball_digest`

A new orchestration method, `_create_provenance_records`, is provided
by the role and is now called from `cmd_create_provenance`.

### Provenance record format (consumed by the signature site)

`_create_provenance_records` emits a JSON record per distribution
(`<basename>.json`) plus a detached ECDSA signature (`<basename>.sig`).
The record carries `digest`/`hash_algo` (the tarball SHA-256),
`botocore` (`{version, commit}`), the source-file digests
(`service-2.json`, `paginators-1.json`), `Amazon::API::BuildInfo::VERSION`
and `GIT_SHA`, `module_name`, and `service`. It is signed over its
**canonical, pretty-printed** JSON — the exact bytes that are published
— so a downloader can re-verify with stock `openssl` against the public
key. The site reads these fields for its per-distribution detail and
`index.json` manifest.

### New File: `Amazon-API.pem` — provenance verification key

The ECDSA P-256 **public key** corresponding to the KMS signing key
(`ECDSA_SHA_256`) is now published so downloaders can verify signed
provenance records offline. It is committed to the repository (the
canonical fingerprint-pinning source) and served from the signature
site at `/signature/Amazon-API.pem`.

---

## Changes

### `Amazon::API::Botocore` (`lib/Amazon/API/Botocore.pm.in`)

- **`render_stub`:** Now raises a hard `croak` if
  `botocore-version.json` cannot be loaded, rather than silently
  defaulting to an empty hash. This prevents difficult-to-diagnose
  failures when building stubs without the required version file
  present.
- **`create_stub`:** Now accepts and forwards a `logger` argument to
  `render_stub`.
- Cleaned up `Cwd` import to use the explicit `getcwd` form.

### `Amazon::API::Provenance` (`lib/Amazon/API/Provenance.pm.in`)

- Now composes the new `Amazon::API::Provenance::Role::Records` role
  via `Role::Tiny::With`.
- **`cmd_create_provenance`:** Refactored to delegate all provenance
  record creation, signing, and verification to the new
  `_create_provenance_records` method provided by the role. The
  tarball basename and version are now computed in this method before
  passing them along.
- Several previously unused imports have been removed
  (`Amazon::API::BuildInfo`, `Amazon::API`, `Digest::SHA`,
  `File::Basename`).

### Dependency Graph (`deps.mk`)

- `Amazon::API::Provenance` now depends on
  `Amazon::API::Provenance::Role::Records` and no longer directly
  depends on `Amazon::API` or `Amazon::API::BuildInfo`.
- `Amazon::API::Provenance::Role::Records` is declared as a new build
  target, depending on `Amazon::API::BuildInfo`.

### `.gitignore`

- Added `bin/amzn-api` to the ignore list.

---

## Upgrade Notes

- No changes to the public API surface of `Amazon::API` or its Botocore shape infrastructure.
- If you have custom code that calls internal methods of
  `Amazon::API::Provenance` (e.g., `_verify_provenance`,
  `_write_provenance_records`, `_sign_provenance_records`,
  `_create_tarball_digest`) directly, these are now provided via
  `Amazon::API::Provenance::Role::Records` and remain callable through
  the `Amazon::API::Provenance` class without any changes to callers.
- Stub generation will now **fail explicitly** if
  `botocore-version.json` is not present in the working directory,
  rather than producing a stub with missing version metadata. Ensure
  this file is present before running `create-stub`.

---

## Full Changelog

See [`ChangeLog`](ChangeLog) for the complete history of changes.
