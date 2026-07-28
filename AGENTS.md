# Tinyrack Dart packages

This repository is a Dart pub workspace containing independently versioned,
public packages.

## Boundaries

- `packages/cliweave` is a general-purpose typed CLI framework.
- `packages/dartage` is a pure-Dart age v1 implementation.
- `packages/shipworld` is reusable release, signing, and desktop-packaging
  tooling. It is published to pub.dev from this workspace via the
  `shipworld-v*` tag trigger, and it consumes `cliweave` from the workspace.
- Keep product-specific types and behavior out of every package.
- Treat each package's public API, README, CHANGELOG, examples, and package
  metadata as user-facing.

## Validation

For every changed package, run:

- `dart format .`
- `dart analyze --fatal-infos`
- `dart test`
- `dart doc`
- `dart pub publish --dry-run`

From the repository root, run `dart run tool/verify_coverage.dart` to check the
95% line-coverage gate (each package independently). `cliweave` and `dartage`
are checked on Linux (`dart run tool/verify_coverage.dart cliweave dartage`);
`shipworld` is checked on **Windows** (`dart run tool/verify_coverage.dart
shipworld`), because its Windows SDK-tool discovery is guarded by
`Platform.isWindows` and only executes on a Windows runner. Passing no package
names runs all three (use that only on Windows).

For `shipworld`, also run `dart run packages/shipworld/tool/validate_standalone.dart`,
which copies the package out of the workspace and runs `pub get`, analyze, test,
`doc`, `publish --dry-run`, and `pana` against pub.dev-resolved dependencies.

For `cliweave`, require the installed completion shells with
`CLIWEAVE_E2E_SHELLS=bash,zsh,fish dart test -t e2e` on Unix and
`$env:CLIWEAVE_E2E_SHELLS='powershell'; dart test -t e2e` in Windows
PowerShell.

For `dartage`, `dart test -x interop` is the offline run. Install the Node
fixture dependencies in `packages/dartage/test/interop` with
`pnpm install --frozen-lockfile`, then run `dart test -t interop` from
`packages/dartage` for reference-implementation interoperability.
