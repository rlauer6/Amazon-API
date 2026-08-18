# Amazon::API 2.6.0 Release Notes

## Overview

Version 2.6.0 is a major refactor focused on reducing distribution
size, eliminating hardcoded metadata, consolidating tooling, and
removing POD generation from API class creation. Generated API classes
are now extremely lightweight.

---

## Breaking Changes

### POD Generation Removed from API Classes

POD generation has been completely removed from the API class creation
process. Documentation (help) is now available exclusively via the
[Amazon-API-Help](https://github.com/rlauer6/Amazon-API-Help) project.

### `Amazon::API::Botocore` Refactored

`Amazon::API::Botocore` has been refactored into
`Amazon::API::Role::Botocore`. The standalone `amazon-api` script has
been removed; all functionality is now consolidated into the
`amzn-api` modulino backed by the new `Amazon::API::CLI` module.

### `bin/build-boto-services.pl` Removed

The standalone `build-boto-services.pl` script has been removed and
its functionality refactored into `Amazon::API::CLI`.

---

## New Features

### `Amazon::API::CLI` (`lib/Amazon/API/CLI.pm`)

A new unified CLI module consolidates the functionality previously
spread across multiple modulinos (`amazon-api`,
`build-boto-services.pl`, and `amzn-api-module-names`). The `amzn-api`
script now dispatches through this module.

### `Amazon::API::Role::Botocore` (`lib/Amazon/API/Role/Botocore.pm`)

Botocore-related functionality has been extracted from
`Amazon::API::Botocore` into a composable role, now used by
`Amazon::API::CLI`, `Amazon::API::Provenance`, and related modules.

### `Amazon::API::Role::ModuleNames` and `Amazon::API::Role::Services`

Previously standalone modules/scripts, these have been refactored as
composable roles consumed by `Amazon::API::CLI`.

### `Amazon::API::BuildInfo::version()`

A new `version()` method provides programmatic access to build
metadata including the pinned Botocore version and commit.

### Botocore Metadata Pinned and Gzip-Compressed

The Botocore version is now pinned from `master` and recorded in
`botocore-version.json`. Per-service API metadata files (`.api`) are
now stored as `.api.gz` (gzip-compressed), significantly reducing CPAN
distribution sizes.

### `share/stub.pm.tmpl`

A new shared stub template is used during API class generation,
replacing the `__DATA__` section previously embedded in
`Amazon::API::Botocore`.

---

## Changes

### `Amazon::API` (`lib/Amazon/API.pm`)

- Added `api_protocol` accessor; protocol detection now sets
  `api_protocol` rather than the generic `protocol` accessor.
- Removed %API_TYPES and @GLOBAL_SERVICES; %SERVICE_CONTENT_TYPES
  relocated to Constants. Content type is now derived from the
  service's Botocore protocol rather than hardcoded service lists.
- `serialize_content`: protocol is read from `api_protocol` rather
  than Botocore metadata directly.
- `_set_content_type`: simplified — no longer consults `%API_TYPES`.
- `_create_service_url`: global endpoint detection now uses Botocore
  metadata exclusively.
- Removed `Module::Load` dependency.

### `Amazon::API::Constants`

- `%SERVICE_CONTENT_TYPES` moved here from `Amazon::API` and is now exported.

### `Amazon::API::Botocore::Shape::Utils`

- Removed `create_shape` and `snake_case` functions (POD generation related).
- Removed `Module::Load` dependency; class loading now uses `require`.

### `Amazon::API::Botocore::Shape::Serializer`

- Removed `Module::Load` dependency.

### `Amazon::API::Template`

- `fetch_template` refactored to use `CLI::Simple::Utils::slurp`.

### `Amazon::API::Provenance`

- Now composes `Amazon::API::Role::Botocore` instead of directly using
  `Amazon::API::Botocore`.

### Build & Distribution

- `botocore.mk` extracted from `project.mk` for cleaner separation of
  Botocore-related build recipes.
- `module-names.json` added to the distribution
  (`module-names-master.json` is the pinned reference copy).
- `buildspec-api.yml.in` updated to reference `.api.gz` artifact.
- `buildspec.yml` updated to include `botocore.mk`,
  `module-names.json`, `botocore-version.json`, and
  `share/stub.pm.tmpl`.
- `project.mk` `cpan-dist` target now calls `get-module-name`
  (previously `module-name`).

### Dependencies

- `Term::ReadKey` removed from `requires`.
- `IO::Pager` and `Perl::Tidy` removed from `suggests`.

### Build Infrastructure

- Minor updates to `Makefile` and `.includes/local.mk` by
  CPAN::Maker::Bootstrapper.
