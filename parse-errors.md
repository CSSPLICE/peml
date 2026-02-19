# PEML Parse Errors Summary

Of 59 `.peml` test inputs, **47 parse cleanly**, **3 parse with diagnostics**, and **9 crash** (errors in `DatadrivenTestRenderer`).

## Files with Schema Validation Diagnostics

### 02-template.peml

| Path | Diagnostic |
|---|---|
| `/license/owner` | is not a string |
| `/license/owner/email` | is not long enough (min 1) |
| `/license/owner/name` | is not long enough (min 1) |

### 03-template-inline.peml

| Path | Diagnostic |
|---|---|
| `/license/owner` | is not a string |
| `/license/owner/email` | is not long enough (min 1) |
| `/license/owner/name` | is not long enough (min 1) |

### experimental.peml

| Path | Diagnostic |
|---|---|
| `/systems/0/environment/start/files` | is not a string |
| `/systems/0/environment/start/files` | array size is less than 1 |
| `/systems/0/environment/start/repository` | does not have sub-keys (wrong structure) |
| `/systems/0/environment/build/files` | is not a string |
| `/systems/0/environment/build/files/0` | is not a string; missing key: content |
| `/systems/0/environment/build/files/1` | is not a string; missing key: content |
| `/systems/0/environment/build/repository` | does not have sub-keys (wrong structure) |
| `/systems/0/environment/run/files` | is not a string |
| `/systems/0/environment/run/files/0` | is not a string; missing key: content |
| `/systems/0/environment/run/files/1` | is not a string; missing key: content |
| `/systems/0/environment/run/repository` | does not have sub-keys (wrong structure) |
| `/systems/0/environment/test/files` | is not a string |
| `/systems/0/environment/test/files/0` | is not a string; missing key: content |
| `/systems/0/environment/test/files/1` | is not a string; missing key: content |
| `/systems/0/environment/test/repository` | does not have sub-keys (wrong structure) |
| `/systems/0/src/files` | is not a string |
| `/systems/0/src/files/0` | is not a string; missing key: content |
| `/systems/0/src/starter/files` | is not a string |
| `/systems/0/src/starter/files/0` | is not a string; missing key: content |
| `/systems/0/src/frame/files` | is not a string |
| `/systems/0/src/frame/files/0` | is not a string; missing key: content |
| `/systems/0/src/solutions` | is not a string |
| `/systems/0/src/solutions/0` | is not a string |
| `/systems/0/src/solutions/0/files` | is not a string |
| `/systems/0/src/solutions/0/files/0` | is not a string; missing key: content |

## Files That Crash During Parsing

These 9 files error in `DatadrivenTestRenderer` before producing output:

| File | Error |
|---|---|
| cw-addThreeCpp.peml | `Errno::ENOENT` — missing Liquid template for language |
| cw-compressString.peml | `Parslet::ParseFailed` — CSV parse error |
| cw-encrypt.peml | `Errno::ENOENT` — missing Liquid template |
| cw-genericsGenericMethod.peml | `NoMethodError` — nil pattern in `generate_methods` |
| cw-genericsGenericMethod2.peml | `NoMethodError` — nil pattern in `generate_methods` |
| cw-getLongestString.peml | `Parslet::ParseFailed` — CSV parse error |
| cw-getMaxLength.peml | `Parslet::ParseFailed` — CSV parse error |
| cw-isUniqueString.peml | `Parslet::ParseFailed` — CSV parse error |
| sumNumbers.peml | `NoMethodError` — nil pattern in `generate_methods` |
