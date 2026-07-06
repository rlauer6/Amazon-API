# Release Notes — Amazon-API v2.4.4

**Date:** Mon Jul 6, 2026
**Author:** Rob Lauer <rclauer@gmail.com>

---

## Bug Fixes

### `Amazon::API::Botocore::Shape::Utils` — Preserve Empty String Values in Parameter Serialization

Fixed a bug in both `param_n` and `query_param_n` where keys with
defined but empty string values (`''`) were being silently dropped
during query parameter serialization.

**Previous behaviour:** Parameters whose values were defined but equal
to the empty string (`''`) were treated the same as `undef` and
discarded.

**New behaviour:** Only `undef` values are dropped. Defined empty
strings (`''`) are now correctly serialized and passed through.

```perl
# Before (2.4.3): empty string value was dropped
# After  (2.4.4): empty string value is preserved
return @param_n
  if !defined $message;   # was: !defined $message || $message eq $EMPTY
```

This fix applies to both `param_n` and `query_param_n`.

---

## Dependency Changes

### Removed

- **`Pod::Markdown`** — removed from both `cpanfile` and
  `requires`. This dependency is no longer required by the
  distribution at runtime.

---

## Build System Changes

### `project.mk` — `cpan` target renamed and refactored to `cpan-dist`

- The `cpan` phony target has been renamed to `cpan-dist` for clarity
  and consistency.
- The `api` sub-target has been refactored into a new
  `workdir/service.api` file target, improving dependency tracking and
  build correctness.
- Consolidated `workdir/service` and `workdir/module` intermediate
  targets into the single `workdir/service.api` target.
- Improved error messaging when `SERVICE` is not specified or an
  unknown service name is provided.
- The `$SCANDEPS` option has been removed from the `cpan-dist` recipe.
- `workdir/buildspec-api.yml` now depends on `workdir/service.api`
  instead of the former separate `workdir/service` and
  `workdir/module` targets.

### `.gitignore`

- Added `workdir/` to `.gitignore` to prevent accidental commits of
  build working directory artefacts.

---

## Tests

### New Test: `t/07-query_param_n.t`

A new test file has been added to provide coverage for the
`query_param_n` function, including the corrected behaviour around
defined-but-empty-string values.

### `test-requires.skip`

- Added `Amazon::API::Botocore::Shape::Utils` to the list of modules
  skipped during test dependency scanning, preventing spurious test
  dependency resolution failures.

---

## Documentation

- **`README.md`** — Updated build prerequisites:
  `CPAN::Maker::Bootstrapper` now requires version `>= 2.0.3`. Added a
  note that additional Perl modules beyond those listed may also be
  required (`...and possibly others`).

---

## Summary of Changed Files

| File | Change |
|---|---|
| `lib/Amazon/API/Botocore/Shape/Utils.pm.in` | Bug fix: `param_n`, `query_param_n` — preserve empty string values |
| `cpanfile` | Removed `Pod::Markdown` dependency |
| `requires` | Removed `Pod::Markdown` dependency |
| `project.mk` | Renamed `cpan` → `cpan-dist`; refactored build targets |
| `t/07-query_param_n.t` | New test for `query_param_n` |
| `test-requires.skip` | Added `Amazon::API::Botocore::Shape::Utils` |
| `README.md` | Updated build prerequisites |
| `.gitignore` | Added `workdir/` |
| `VERSION` | Bumped to `2.4.4` |
| `ChangeLog` | Updated |
