# Release Notes: Amazon::API 2.4.5

**Released:** Thu Jul 16 2026  
**Author:** Rob Lauer <rclauer@gmail.com>

---

## Overview

Version 2.4.5 introduces Botocore metadata support, a new
`amzn-api-module-names` utility, and a new `Amazon::API::ModuleNames`
module. This release also includes several bug fixes and build system
improvements.

---

## New Features

### Botocore Metadata API (`botocore-metadata.api`)

A new build artifact, `botocore-metadata.api`, is now generated as
part of the build process and included in the CPAN distribution. This
file aggregates metadata from all Botocore service definitions.

- Added `botocore-metadata.api` to `buildspec.yml` as an extra distribution file
- Added new `botocore-metadata.api` build target in `project.mk`
- Added `botocore-metadata.api` to `.gitignore`

### New `amzn-api-module-names` Utility

A new command-line utility (`bin/amzn-api-module-names`) has been
introduced to manage and create AWS API module name mappings.

- New `bin/amzn-api-module-names.in` script
- New `$CREATE_MODULE_NAMES` make variable and build target in `project.mk`
- Added `bin/amzn-api-module-names` to `.gitignore`

### New `Amazon::API::ModuleNames` Module

A new `lib/Amazon/API/ModuleNames.pm.in` module has been added to
support module name management.

### `module_names.json`

A new `module_names.json` data file has been added to the project to
provide a mapping of Botocore service names to Perl module names.

### `amazon-api module-name`

A new utility function has been added to output the canonical module
name for a give service.

---

## Enhancements

### `Amazon::API::Botocore`

- **`find_latest_services`:** The `%BOTO_SERVICES` hash now also
  stores the full `file` path (joined from the path components) for
  each discovered service, enabling easier direct file access.
- **`render_stub`:** Output directories for method POD files are now
  created automatically using `File::Path::make_path` if they do not
  already exist, preventing file write failures.
- **`fetch_boto_services`:** Accepts an optional `$metadata`
  argument. When provided, the full service metadata (parsed from
  JSON) is loaded into `%BOTO_SERVICES` for each service entry via
  `CLI::Simple::Utils::slurp_json`.
- Added `CLI::Simple::Utils` (`slurp_json`) and `File::Basename`
  (`dirname`) as new dependencies.
- Updated version POD to distinguish between the Botocore version and the `Amazon::API` version.

### `Amazon::API::Template`

- Minor cleanup: removed a trailing comment from the `fetch_template`
  subroutine.

---

## Build System Changes

### `project.mk`

- Added `CREATE_MODULE_NAMES` variable pointing to
  `bin/amzn-api-module-names`.
- Added build rule for `$(CREATE_MODULE_NAMES)`.
- Added `botocore-metadata.api` build target that depends on
  `module_names.json`, `$(BOTOCORE_STATE)`, and
  `$(CREATE_MODULE_NAMES)`.
- Updated `cpan-dist` target: removed trailing backslash from the `cp`
  command (minor Makefile fix).
- Updated `cpan-dist` to use `amazon-api module-name` eliminating need
  to pass MODULE_ALIAS when creating an API class
- Updated `workdir/service.api` target: added `--pod` flag to
  `amazon-api` invocations for `create-stub` and `create-shape`.
- Added `clean-local` target to remove the `workdir` directory during
  cleaning.

### `Makefile`

- Updated `clean` target to `clean::` with prerequisite `clean-local`,
  supporting Makefile double-colon rule chaining (as updated by
  `CPAN::Maker::Bootstrapper`).

---

## Bug Fixes

- Fixed a potential failure in `render_stub` where writing POD output
  files would fail if the target directory had not been created.
- Fixed the `find_latest_services` hash assignment for the `file` key
  (corrected quoting in the `join` call).

---

## Files Changed

| File | Change |
|---|---|
| `VERSION` | Bumped to `2.4.5` |
| `.gitignore` | Added `botocore-metadata.api`, `bin/amzn-api-module-names` |
| `Makefile` | Updated by `CPAN::Maker::Bootstrapper`; `clean` → `clean::` |
| `buildspec.yml` | Added `botocore-metadata.api` to extra-files |
| `lib/Amazon/API/Botocore.pm.in` | See enhancements above |
| `lib/Amazon/API/Template.pm.in` | Minor comment removal |
| `project.mk` | New targets and variables; see build system changes |
| `bin/amzn-api-module-names.in` | **New file** |
| `lib/Amazon/API/ModuleNames.pm.in` | **New file** |
| `module_names.json` | **New file** |
| `release-notes/release-notes-2.4.4.md` | New release notes for prior release |

---

## Upgrade Notes

No breaking changes are introduced in this release. The new
`fetch_boto_services($path, $metadata)` signature is
backward-compatible; existing callers passing only `$path` are
unaffected.
