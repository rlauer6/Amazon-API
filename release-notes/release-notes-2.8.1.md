# Amazon::API 2.8.1 Release Notes

## Overview

Version 2.8.1 is a maintenance and polish release. It introduces a
pre-built Docker image for trying `Amazon::API` without a local
installation, improves build tooling through updated
`CPAN::Maker::Bootstrapper` integration, fixes several documentation
errors, and adds a `NOTICE` file and DockerHub support.

---

## What's New

### Docker Image on DockerHub

You can now try `Amazon::API` without installing anything locally. A
pre-built image is available at
[`rlauer/amazon-api`](https://hub.docker.com/r/rlauer/amazon-api) on
DockerHub.

```bash
docker run --rm \
  -v "$HOME/.aws:/root/.aws:ro" \
  -e AWS_PROFILE=my-profile \
  rlauer/amazon-api:latest \
  perl -MAmazon::API::STS -MData::Dumper \
       -e 'print Dumper(Amazon::API::STS->new->GetCallerIdentity)'
```

Supporting files added to the project:

- `Dockerfile.dockerhub` — Docker image definition for DockerHub
- `dockerhub.mk` — build automation for the DockerHub image
- `NOTICE` — generated from `NOTICE.in` with Botocore version metadata

### New FAQ Entry: Querying the Botocore Version

A new FAQ entry in `Amazon::API` documentation explains how to query
the Botocore version that the distribution was built against:

```perl
use Amazon::API::BuildInfo;

my ($version, $commit) =
    Amazon::API::BuildInfo->botocore_version;
```

---

## Build System Improvements

These changes update the `CPAN::Maker::Bootstrapper`-managed build
infrastructure.

### Dependency Installation (`local.mk`)

- The `local` target is now tracked via a sentinel file
  (`local/.installed`) to avoid unnecessary reinstallation.
- Runtime and test dependencies are now installed separately:
  - Runtime: from `cpanfile.runtime` (derived from `requires`)
  - Test: from `test-requires.cpanfile` (derived from `test-requires`)
- Both `cpm` and `carton` installers now respect the two-cpanfile split.

### Test Dependency Scanning (`Makefile`)

- `test-requires.scan` now excludes modules that are already provided
  by the distribution itself (`provides` target), preventing false
  test-only dependency entries.
- `PERL5LIB` is now set correctly during scanning so locally installed
  modules are found.
- A new `cpanfile.runtime` target generates a cpanfile from `requires`
  alone (without test dependencies), used for local installation.
- The `extra-files` target now uses `extra-files.skip` to filter files
  that should not be tracked, and validates that all listed extra
  files are tracked in git.
- `extra-files.mk` is no longer included during bootstrap builds
  (`BOOTSTRAP_BUILD`).
- `find-files` macro now supports an optional fourth pattern argument
  (used to include `*.pm` and `*.pl` files alongside `*.t` in the test
  file list).
- `$(TARBALL)` build now prepends `local/lib/perl5` to `PERL5LIB`.

### Syntax and Lint Checking (`perl.mk`)

- Check output is now more informative: each step prints the file
  being checked and an `OK` confirmation.
  - e.g. `Checking SYNTAX...lib/Amazon/API.pm...OK`
  - e.g. `Checking POD...lib/Amazon/API.pm...OK`
  - e.g. `Checking TIDINESS...lib/Amazon/API.pm...OK`
  - e.g. `Checking PERLCRITIC...lib/Amazon/API.pm...OK`
- `perlcritic` output is suppressed from stdout during normal checking (only displayed on failure).
- `LOCAL_PREREQ` now correctly depends on `local/.installed` rather than the `local` phony target.

### Update Management (`update.mk`)

- `bootstrap.mk` is now included in the set of managed files updated by `make update`.

### `.gitignore`

- Added ignore patterns for: `*.bak`, `*.log`, `*.pod`, `*.tmp`, editor swap files (`.#*`, `#*`), `cpanfile.*`, `test-requires.cpanfile`, `test-requires.scan`.
- Removed `NOTICE` from `.gitignore` (it is now a tracked, generated file).

---

## Documentation Fixes

Several errors and outdated content were corrected across the POD
documentation.

### `Amazon::API`

| Location | Fix |
|---|---|
| `DESCRIPTION` | Removed stale GitHub Actions build badge and its surrounding `=begin markdown` block |
| `DESCRIPTION` | "generates" → "generate" |
| `BACKGROUND AND MOTIVATION` | "handfull" → "handful" |
| Example command | Fixed class name typo: `Amazon::STS::API::STS` → `Amazon::API::STS` |
| Constructor example | `Amazon::Credential->new()` → `Amazon::Credentials->new()` (missing `s`) |
| Botocore corpus count | Changed specific counts (632/31) to "600+" and "30+" to avoid stale figures |
| `Why not Paws?` | "If you don't want to install of the AWS services" → "install all of the AWS services" |
| Debugging section | "Excecute" → "Execute" |
| DarkPAN link | Fixed reference from generic `L</Amazon::API>` to `L<website|https://cpan.openbedrock.net/signature>` |
| Stability FAQ | Removed version-specific bug count claim |

### `Amazon::API::BuildInfo`

- Replaced non-ASCII em-dash characters (`â`) with standard ASCII
  hyphens (`-`) for compatibility.

### `Amazon::API::Provenance`

- Updated example filenames from date-based
  (`Amazon-API-STS-2011.06.15`) to version-based
  (`Amazon-API-STS-1.43.103`) format, matching actual distribution
  naming.
- Updated public key filename references: `provenance-pub.pem` → `Amazon-API.pem`.
- Updated `verify.sh` accordingly.

### `Amazon::API::Role::Botocore`

- Replaced non-ASCII em-dash characters with standard ASCII hyphens in
  POD.

### `Amazon::API::Signature4`

- Replaced non-ASCII em-dash character with a standard hyphen in an
  inline comment.

---

## Other Changes

- `verify.sh` — marked executable (`chmod +x`)
- `extra-files.skip` — new file for listing extra files to exclude
  from distribution tracking

---

## Upgrade Notes

This is a non-breaking maintenance release. No API changes were
made. Upgrading from 2.8.0 requires no changes to calling code.
