# Amazon::API 2.7.0 Release Notes

## Overview

Version 2.7.0 introduces a new, more capable pagination system
(`Amazon::API::Paginator` and `Amazon::API::Paginator::Compiler`) that
supersedes the legacy paginator, while maintaining full backward
compatibility. This release also includes safety improvements to the
legacy paginator and enhancements to the Botocore stub metadata
format.

---

## New Features

### New Paginator Architecture

Two new modules have been introduced to replace the legacy paginator
with a more robust, compiled approach:

- **`Amazon::API::Paginator`** — A runtime pagination engine that
  manages multi-page API responses, tracking state across pages and
  assembling final results.
- **`Amazon::API::Paginator::Compiler`** — A compile-time compiler
  that pre-processes raw Botocore paginator definitions (including
  complex cases with array tokens, `more_results` expressions, and
  `non_aggregate_keys`) into an optimized form stored in the `.api.gz`
  metadata file.

The new paginator handles a wider range of Botocore pagination
patterns, including:
- Array-valued `input_token` / `output_token`
- Complex `more_results` expressions
- `non_aggregate_keys` (pass-through fields)

### New Accessor: `compiled_paginators`

A new `compiled_paginators` accessor has been added to
`Amazon::API`. Pre-compiled paginator definitions are now stored in
the `.api.gz` metadata blob at stub generation time and loaded
automatically at runtime by generated service stubs.

### New Accessor: `use_legacy_paginator`

A new `use_legacy_paginator` accessor (default: `false`) allows opting
back into the legacy paginator when needed. The legacy paginator
remains fully supported for services whose pagination patterns it
handles.

---

## Changes

### `Amazon::API` (`lib/Amazon/API.pm.in`)

#### `invoke_api`
- Implements the new paginator path when `compiled_paginators` are
  available and `use_legacy_paginator` is `false`.
- Falls back to the legacy paginator when `use_legacy_paginator` is
  `true` or no compiled paginators are present.
- **Safety:** Croaks with a clear error if a legacy paginator
  definition exists for an action but no compiled paginator definition
  is found, preventing silent pagination failures.
- **Infinite loop guard:** The legacy paginator now detects when the
  same continuation token is returned twice and croaks with a
  descriptive error rather than looping indefinitely.

#### `_init_paginator`
- Now reads from `$paginators->{pagination}` (the correct Botocore
  structure) rather than the top-level paginators hash.
- Validates that scalar-required paginator markers (`input_token`,
  `output_token`, `result_key`) are defined and non-reference.
- Validates that optionally-scalar markers (`limit_key`,
  `more_results`) are not references when defined.
- Croaks explicitly when a paginator definition includes
  `non_aggregate_keys`, which the legacy paginator cannot handle —
  rather than silently producing incorrect results.

#### `set_defaults`
- `use_legacy_paginator` now defaults to `false`.

### `Amazon::API::Role::Botocore` (`lib/Amazon/API/Role/Botocore.pm.in`)

#### `create_stub`
- Instantiates `Amazon::API::Paginator::Compiler` during stub
  generation and stores the resulting compiled paginator definitions
  into the `.api.gz` metadata file alongside the existing raw
  paginators, shapes, and operations.

### `share/stub.pm.tmpl`

- Generated service stubs now prefer the `.api.gz` (gzip-compressed)
  metadata file over the uncompressed `.api` file when both are
  present, improving load performance.
- Generated `new()` methods now pass `compiled_paginators` (loaded from the metadata file) into the `Amazon::API` constructor.

---

## Testing

- **`t/paginator.t`** — New test suite for `Amazon::API::Paginator`.
- **`t/paginator-compiler.t`** — New test suite for
  `Amazon::API::Paginator::Compiler`.

---

## Dependency Notes

`Amazon::API::Paginator` and `Amazon::API::Paginator::Compiler` are
excluded from `test-requires` dependency scanning (added to
`test-requires.skip`) as they are internal to this distribution.

---

## Upgrade Notes

- **No breaking changes.** Existing generated service stubs continue
  to work. Stubs regenerated with this version will include compiled
  paginators and will use the new paginator by default.
- Services whose paginators use array tokens, compound `more_results`
  expressions, or `non_aggregate_keys` will now paginate correctly
  where they previously would have croaked or produced incomplete
  results under the legacy paginator.
- To opt into legacy pagination behaviour explicitly, set
  `use_legacy_paginator => 1` when constructing a service object.
