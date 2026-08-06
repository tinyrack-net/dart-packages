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

## Merging

Everything reaches `main` through a pull request and a merge queue. Nobody
bypasses the queue, so `gh pr merge --admin` and a direct push both fail.

Mark a pull request ready with `gh pr merge <number> --auto` ("Merge when
ready"). Pass no merge method: the queue sets it, and `--squash` only earns a
warning. It enters the queue once its checks pass and any review
threads are resolved, CI re-runs against `main` merged with the entry, and it
squashes onto `main` only if that run is green. A queued entry that fails is
dropped back out, so watch for a pull request that silently leaves the queue —
a dependency published between the two runs is the usual cause, since
`pubspec.lock` is deliberately not committed.

`Quality Gate` is the only status check `main` requires. It succeeds only when
every other job in `ci.yml` succeeds, which means:

- Renaming a job or a matrix leg is safe; renaming `Quality Gate` is not. The
  queue reports the new name while branch protection still waits for the old
  one, and the entry is evicted an hour later with no useful error.
- A new job must be added to `quality-gate`'s `needs`. One left out is exempt
  from the gate, and nothing reports the omission.
