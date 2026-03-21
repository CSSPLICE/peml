# SPEC.md — Project Specification

> **Status**: `FINALIZED`

## Vision
Refactor the `TRANSFORMS` operations in `lib/peml.rb` to support a unified diagnostic reporting pipeline. Transformations will receive both the current data value and accumulated diagnostics, allowing them to append their own diagnostic messages during the transformation phase.

## Goals
1. Move the `validate()` call to occur immediately after the initial load, before transformations.
2. Modify the structure passed to `TRANSFORMS` procs to be a hash containing `{'value' => value, 'diagnostics' => diags}`.
3. Update all individual transformation methods to accept and return/mutate this hash structure instead of just the data value.

## Non-Goals (Out of Scope)
- Adding new transformation features.
- Changing the parsing logic of the loader or parser.

## Users
Developers using the PEML ruby gem who require detailed diagnostics and error reporting not just from initial parsing/validation, but also from the transformation stages (e.g., rendering tests or interpolating data).

## Constraints
- Must maintain backward compatibility for users requesting `result_only`.
- The `datadriven_test_renderer.rb` module must also be updated in tandem.

## Success Criteria
- [ ] `Peml.parse(params)` validates structural integrity before applying transformations.
- [ ] All methods referenced in `Peml::TRANSFORMS` accept the `{'value' => ..., 'diagnostics' => ...}` hash.
- [ ] Existing test cases pass, confirming no breaking structural changes for default usages.
