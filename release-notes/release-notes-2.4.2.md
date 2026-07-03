# Release Notes — Amazon::API 2.4.2

**Release Date:** 2026-07-02
**Distribution:** Amazon-API
**Author:** Rob Lauer <rclauer@gmail.com>

---

## Overview

Version 2.4.2 is a maintenance release focused on build tooling
improvements, dependency hygiene, and compatibility fixes for static
dependency scanning. No changes have been made to the public API
behaviour.

---

## What's New

### Bug Fixes

#### `Amazon::API` — `require` instead of `load` for static scanning

Several methods in `lib/Amazon/API.pm.in` were updated to use
`require` instead of `Module::Load::load` so that `scandeps-static.pl`
can correctly detect runtime dependencies during the build process:

- `paginator` — now uses `require Amazon::API::Botocore`
- `decode_response` — now uses `require XML::Simple`
- `generate_xml` — now uses `require XML::Twig`
- `_set_default_logger` — now uses `require Log::Log4perl`

#### `Amazon::API::Botocore::Shape::Utils` — `require_class` fix

The `require_class` function in
`lib/Amazon/API/Botocore/Shape/Utils.pm.in` was updated to use `load`
instead of `require` inside an `eval` block. This avoids a spurious
`perlcritic` finding while preserving the correct dynamic loading
behaviour.

---

## Build System Changes

### Makefile / `CPAN::Maker` migration

- Replaced `make-cpan-dist.pl` with the new `cpan-maker` command
  throughout `Makefile`.
- The `cpanfile` target now delegates to `cpan-maker create-cpanfile`
  instead of manually concatenating and sorting `requires` and
  `test-requires`.
- `MODULE_NAME` derivation fixed: `$(pwd)` was incorrectly expanded at
  make parse time; corrected to `$$(pwd)`.
- `GIT_NAME`, `GIT_EMAIL`, and `GITHUB_USER` git config lookups now
  redirect stderr to `/dev/null` to suppress warnings in environments
  without git config.
- A hard error is now raised at parse time if
  `CPAN::Maker::Bootstrapper` is not installed.
- `SCAN` is automatically set to `OFF` when `scandeps-static.pl` is
  not found, rather than defaulting to `ON` unconditionally.
- Warning emitted (not error) when `Markdown::Render` (`md-utils.pl`)
  is not installed.
- `README.md` generation rules made conditional: both the
  pod-from-module path and the `README.md.in` path now gracefully fall
  back to copying the source file if the required tools are absent.
- Removed the `@EXTRA_FILES@` substitution placeholder from the `buildspec.yml` generation rule.
- `$(MODULE_PATH).in` rule: `module.pm.tmpl` is now an explicit
  dependency (not order-only), and the template file is removed after
  use.

### `.includes/perl.mk` improvements

- Removed the unconditional `PODEXTRACT` lookup from the top-level
  variable block; `podextract` is still used when
  `POD=extract|remove`, but the `run_podextract` snippet now emits a
  clear error message and exits if the binary is not found.
- `tidy_on` and `critic_on` are now only defined when `PERLTIDY` /
  `PERLCRITIC` binaries are found on `PATH`, preventing spurious lint
  failures in minimal environments.
- Fixed a double-redirect typo in the `diff` invocation inside the
  `.pl.tdy` sentinel rule (`2>/dev/null 2>&1` → `2>/dev/null`).
- The `.pl` syntax-check snippet no longer loads a module with `-M`
  (was incorrectly passing `-M"$$module"` for script files).

### `builder` CI script

- `EXTRA_DEPS` no longer explicitly pins `Module::ScanDeps::Static`;
  it is pulled in transitively.
- Version comparison in the `cpanfile` generation one-liner fixed: `$v
  =~/\s*0\s*/` replaced with the simpler `$v eq q{0}` to avoid false
  matches.
- `git clone $REPO` no longer guards against an existing checkout
  (removed the `test -d … || git clone` guard) to ensure a clean clone
  on every CI run.

---

## Dependency Changes

### Runtime (`requires` / `cpanfile`)

The following modules were **removed** from the runtime dependency list:

| Module | Reason |
|---|---|
| `Carp::Always` | Not a runtime requirement |
| `URI` | Moved to test-requires |
| `Pod::Parse` | Typo / not used |
| `Pod::Text` | Not a direct dependency |
| `Pod::Simple` | Not a direct dependency |
| `HTTP::Headers` | Pulled in transitively |
| `Date::Format` | Not used at runtime |

The following modules had version constraints **updated or added**:

| Module | New Minimum Version |
|---|---|
| `CLI::Simple` | 2.0.7 (was 2.0.6) |
| `CPAN::Maker` | 2.0.1 (was unversioned) |
| `Log::Log4perl` | 1.57 |
| `HTTP::Tiny` | 0.088 |
| `List::Util` | 1.63 |

`Markdown::Render` was added to `build-requires`.

### Test (`test-requires`)

`test-requires` was trimmed and now contains only:

```
HTTP::Request 7.01
URI 5.34
```

(`Test::More` was removed as it is a core module.)

### New file: `test-requires.skip`

A new `test-requires.skip` file was introduced to prevent
`Amazon::API` and `Amazon::API::Signature4` from being listed as test
dependencies of themselves during dependency scanning.

---

## Documentation

- `README.md` was replaced with a maintainer-oriented build guide
  (previously the full module POD was rendered here). The full module
  documentation remains available via `perldoc Amazon::API` and on
  MetaCPAN.
- A new `README.md.in` template file was added as the source for
  `README.md` generation.
- A new `llm-release-notes` convenience target was added to
  `project.mk` to assist with AI-assisted release note generation.

---

## Upgrade Notes

- If you use the build tooling directly, ensure `CPAN::Maker` >= 2.0.1
  and `Markdown::Render` are installed before running `make`.
- If `Perl::Tidy` or `Perl::Critic` are not installed, pass `LINT=off` to suppress related errors:
  ```
  make LINT=off
  ```
- The `cpanfile` in this release reflects runtime dependencies
  only. CI builds install additional dependencies from
  `build-requires` and `test-requires` via the `builder` script.
  
