# Release Notes - Amazon::API v2.4.3

**Release Date:** July 4, 2026
**Author:** Rob Lauer <rclauer@gmail.com>

---

## Overview

This is a maintenance release focused on build tooling modernization,
dependency management improvements, and POD documentation fixes. No
changes were made to the core `Amazon::API` runtime behavior.

---

## What's Changed

### Build System

- **Migrated release notes generation to `CPAN::Maker::Bootstrapper`**
  — The `release-notes` make target has been simplified to delegate
  entirely to `bootstrapper release-notes`, replacing the previous
  bespoke shell script that produced `.diffs`, `.lst`, and `.tar.gz`
  artifacts.

- **Switched CPAN distribution maker to `cpan-maker`** — The
  `CPAN_DIST_MAKER` variable in `project.mk` has been updated from
  `make-cpan-dist.pl` to `cpan-maker`.

- **Removed `$SCANDEPS` option from `cpan-dist` target** — The
  `--scandeps` / `-s` flag is no longer passed to the CPAN
  distribution maker.

- **CPAN tarball now copied to the working directory** — The
  `cpan-dist` make target now copies the generated `.tar.gz` to the
  project root after a successful build.

- **Fixed `workdir/buildspec-api.yml` dependencies** — The target now
  correctly depends on `workdir/service` and `workdir/module`, and
  reads from those files instead of the bare `service` and `module`
  files.

- **Removed `llm-release-notes` make target** — This functionality is
  now handled entirely by `CPAN::Maker::Bootstrapper`.

- **Fixed `builder` script `cd` command** — Changed `cd $(basename
  $REPO .git)` to `cd $dir` for correctness.

- **Builder no longer pins `CPAN::Maker` and
  `CPAN::Maker::Bootstrapper` versions** — The `EXTRA_DEPS` array in
  the `builder` script now installs the latest available versions
  rather than specific pinned versions (version pinning has moved to
  `build-requires`).

### Dependencies

- **Updated `build-requires`** — `CPAN::Maker` is now pinned to `>=
  2.0.1` and `CPAN::Maker::Bootstrapper` to `>= 2.0.4`.

- **`cpanfile` sorted alphabetically** — All `requires` entries are
  now sorted for easier maintenance and diff readability. No runtime
  dependencies were added or removed.

- **`README.md.in` updated** — Documents the minimum required
  versions: `CPAN::Maker >= 2.0.1` and `CPAN::Maker::Bootstrapper >=
  2.0.3`, and notes that additional build dependencies may be
  required.

### Documentation / POD Fixes

- **Fixed POD structure in `lib/Amazon/API.pm.in`** — Corrected the
  `=begin`/`=end` block delimiters:
  - Added missing `=pod` directive before the `=begin 'ignore'` block.
  - Changed `=begin markdown` / `=end markdown` / `=pod` sequence to
    the correct `=begin 'markdown'` / `=end 'markdown'` form,
    preventing POD parsers from misinterpreting the GitHub Actions
    badge section.

---

## Upgrade Notes

- If you maintain or build this distribution from source, ensure you
  have **`CPAN::Maker >= 2.0.1`** and **`CPAN::Maker::Bootstrapper >=
  2.0.4`** installed before running `make release-notes` or `make
  cpan-dist`.
- The `bootstrapper` binary must be available in your `PATH` for the
  `release-notes` target to function.
- No changes to the installed Perl module API or runtime behavior —
  downstream users of `Amazon::API` on CPAN are unaffected.

---

## Previous Release

See [release notes for v2.4.2](/release-notes/release-notes-2.4.2.md) for the previous release.
