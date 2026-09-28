# Release Notes — Amazon::API 2.8.2

## Overview

Version 2.8.2 eliminates the hard runtime dependency on `CLI::Simple`
by introducing a new internal utility module (`Amazon::API::Utils`)
and replacing all internal uses of `CLI::Simple::Utils` and
`CLI::Simple::Constants`. `CLI::Simple` is now an optional suggested
dependency, loaded on demand only when the modulino CLI entry points
are invoked directly.

---

## New Features

### `Amazon::API::Utils` — New Internal Utility Module

A new module, `Amazon::API::Utils`, has been introduced to house
utility functions (e.g. `slurp`, `slurp_json`, `choose`) previously
imported from `CLI::Simple::Utils`. This removes the mandatory
dependency on `CLI::Simple` for all non-CLI consumers of
`Amazon::API`.

### Lazy Loading of `CLI::Simple` in Modulino Entry Points

`Amazon::API::CLI` and `Amazon::API::Provenance` now defer loading of
`CLI::Simple` until they are actually invoked as modulinos (i.e. when
the `MODULINO_WRAPPER` environment variable is set). A clear error
message is emitted if `CLI::Simple` is not installed and a CLI command
is attempted:

```
CLI::Simple is required to use the Amazon::API CLI
```

### New Build Targets

- **`test-local`** — Runs unit tests and endpoint resolver tests
  against a local Botocore checkout (requires `BOTOCORE_PATH`).
- **`full-test`** — Runs unit tests, endpoint tests, and Botocore
  protocol corpus tests in sequence.
- **`build-requires.cpanfile`** / **`local/.build-requires`** —
  Automatically generates and installs build-time dependencies via
  `cpm` from the `build-requires` file.

---

## Changes

### Dependency Changes

| Dependency | Change |
|---|---|
| `CLI::Simple` | Removed from runtime `requires`; added to `suggests` (≥ 2.2.2) |
| `CLI::Simple::Utils` | Removed from runtime `requires` |
| `CLI::Simple::Constants` | Removed from runtime `requires` |
| `List::MoreUtils` | Removed |
| `JSON::PP` | Version constraint relaxed to `0` (any version) |
| `CLI::Simple` | Added to `build-requires` (for build tooling only) |

### Internal Refactoring — `CLI::Simple` Removal

All internal modules have been updated to import from
`Amazon::API::Utils` and `Amazon::API::Constants` instead of
`CLI::Simple::Utils` and `CLI::Simple::Constants`:

- `Amazon::API::BuildInfo`
- `Amazon::API::CLI`
- `Amazon::API::EndpointResolver`
- `Amazon::API::Provenance`
- `Amazon::API::Provenance::Role::Records`
- `Amazon::API::Provenance::Role::SSM`
- `Amazon::API::Role::Botocore`
- `Amazon::API::Role::ModuleNames`
- `Amazon::API::Role::Services`
- `Amazon::API::Template`

### `Amazon::API::Role::Botocore` — Removed `List::MoreUtils` Dependency

The `find_latest_services` function previously used
`List::MoreUtils::first_index`. This has been replaced with an
equivalent inline loop, removing the `List::MoreUtils` dependency
entirely.

### Test Suite Updates

All endpoint resolver tests (`t/14-endpoint-resolver.t` through
`t/22-endpoint-resolver.t`) have been updated to import `slurp_json`
from `Amazon::API::Utils` instead of `CLI::Simple::Utils`.

The `test-requires.skip` file has been cleared (all entries removed)
following a fix in `CPAN::Maker::Bootstrapper`.

### Docker Image Improvements

- `Dockerfile.dockerhub` now accepts `AMAZON_API_VERSION` as a
  required build argument (no default hardcoded version).
- The local distribution tarball is copied into the image at build
  time and installed directly via `cpm`, rather than pulling from
  CPAN.
- Docker login and image push have been split into a separate
  `publish-image` target in `dockerhub.mk`, decoupling image build
  from publication.

### Legacy Docker Infrastructure Removed

The following files in the `docker/` directory have been deleted as
they are no longer maintained or used:

- `docker/Dockerfile`
- `docker/Dockerfile.rpm-build`
- `docker/Makefile.docker`
- `docker/README.md`
- `docker/build-dist`
- `docker/create-cpan-dist`
- `docker/docker-compose.yaml`
- `docker/package-create-service.lst`
- `docker/package-rpm-build.lst`
- `docker/rpm-build`

### Build System

- The build no longer pulls the latest Botocore version by default.
  Botocore is now deliberately pinned to a specific release and must be
  advanced explicitly with `make update-botocore`. Distribution builds
  will warn when a newer Botocore release is available without changing
  the pinned version.
- The `install` target now uses `cpm` instead of `cpanm`.
- `botocore-metadata.api` and `services.api` build targets now depend
  on `local/.build-requires` to ensure build-time dependencies are
  installed before Botocore processing begins.
- `test-requires.raw` generation now normalises `0` version
  constraints to `undef` before comparison to avoid false positives in
  `comm`.

---

## Upgrade Notes

- `CLI::Simple` is no longer installed as a required dependency. If you
  use the `amzn-api` or `amzn-api-provenance` command-line tools,
  install `CLI::Simple` (>= 2.2.2) separately:
