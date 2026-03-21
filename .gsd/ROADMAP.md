# ROADMAP.md

> **Current Phase**: Completed
> **Milestone**: v1.0

## Must-Haves (from SPEC)
- [x] Move validation before transformations in `parse()`
- [x] Pass `{'value' => value, 'diagnostics' => diags}` hash to transformations
- [x] Update individual transformation methods to accept the state hash

## Phases

### Phase 1: Core Parsing Pipeline Refactor
**Status**: ✅ Completed
**Objective**: Restructure `Peml.parse` to evaluate `validate(value)` early and set up the new transport hash.

### Phase 2: Updating Transformation Methods
**Status**: ✅ Completed
**Objective**: Update all methods routed by `TRANSFORMS` (`inline_urls`, `inline_data_files`, `render_datadriven_tests!`, `interpolate`, `render_to_html`) to accept the new hash parameter. Modification required in `lib/peml.rb` and `lib/peml/datadriven_test_renderer.rb`.

### Phase 3: Testing and Verification
**Status**: ✅ Completed
**Objective**: Run the minitest harness (`bundle exec rake test`) to ensure everything still passes and diagnostics are correctly aggregated.
