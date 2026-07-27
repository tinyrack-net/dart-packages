# Tinyrack Dart packages

This repository is a Dart pub workspace containing independently versioned,
public packages.

## Boundaries

- `packages/cliweave` is a general-purpose typed CLI framework.
- `packages/dartage` is a pure-Dart age v1 implementation.
- Keep product-specific types and behavior out of both packages.
- Treat each package's public API, README, CHANGELOG, examples, and package
  metadata as user-facing.

## Validation

For every changed package, run:

- `dart format .`
- `dart analyze --fatal-infos`
- `dart test`
- `dart doc`
- `dart pub publish --dry-run`

From the repository root, also run `dart run tool/verify_coverage.dart`. Each
package must independently meet the 95% line coverage gate.

For `cliweave`, require the installed completion shells with
`CLIWEAVE_E2E_SHELLS=bash,zsh,fish dart test -t e2e` on Unix and
`$env:CLIWEAVE_E2E_SHELLS='powershell'; dart test -t e2e` in Windows
PowerShell.

For `dartage`, `dart test -x interop` is the offline run. Install the Node
fixture dependencies in `packages/dartage/test/interop` with
`pnpm install --frozen-lockfile`, then run `dart test -t interop` from
`packages/dartage` for reference-implementation interoperability.
