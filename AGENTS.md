# Tinyrack Dart packages

This repository is a Dart pub workspace containing independently versioned,
public packages.

## Boundaries

- `packages/cliweave` is a general-purpose typed CLI framework.
- `packages/dartage` is a pure-Dart age v1 implementation.
- `packages/ptyworld` is cross-platform pseudo-terminal process support. It is
  the only package here that builds native code: `hook/build.dart` compiles
  `src/ptyworld.c` into a C native asset on Linux, macOS, and Windows. It is
  not published to pub.dev yet, so it is the one package with no `dart doc` or
  `dart pub publish --dry-run` check; consumers pin it by commit SHA.
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
95% line-coverage gate (each package independently). `cliweave`, `dartage`, and
`ptyworld` are checked on Linux; `shipworld` is checked on **Windows**
(`dart run tool/verify_coverage.dart shipworld`), because its Windows SDK-tool
discovery is guarded by `Platform.isWindows` and only executes on a Windows
runner. Passing no package names runs all four (use that only on Windows).

In CI this is not a separate job: one leg of each package's test matrix runs
`verify_coverage.dart` instead of `dart test`, because the script already runs
the same suite with the same exclusions. Adding a plain `dart test` step back to
that leg only doubles its runtime.

`ptyworld` covers its operating-system failure branches by substituting
`PtyBindings` through `PtyProcess.withBindings`. A fake must also stub
`attachFinalizer`/`detachFinalizer`: handing a placeholder handle to the real
`NativeFinalizer` frees a fabricated pointer during a later collection and
crashes the test isolate.

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
every other job in `ci.yml` either succeeds or is skipped as unaffected, which
means:

- Renaming a job or a matrix leg is safe; renaming `Quality Gate` is not. The
  queue reports the new name while branch protection still waits for the old
  one, and the entry is evicted an hour later with no useful error.
- A new job must be added to `quality-gate`'s `needs`. One left out is exempt
  from the gate, and nothing reports the omission.

## Affected packages

A pull request only runs the jobs for the packages it touches. The `affected`
job runs `tool/affected_packages.dart`, which derives the workspace graph from
the pubspecs and emits one boolean output per member, closed over dependents:
changing `cliweave` also runs `shipworld`, which consumes it. `push` to `main`
and `merge_group` skip the diff and run everything, because the queue resolves
dependencies against a moving `main` with no committed `pubspec.lock`.

A path that the tool does not recognise runs the full suite. Keep that
direction: a new top-level directory should cost extra CI, never silently exempt
itself. Only root `*.md` and `LICENSE` are treated as affecting nothing.

The gate accepts a skipped job, which is safe for exactly one reason: every
gated job's `if:` reads `needs.affected` and nothing else, and the gate asserts
`affected` itself succeeded. Give one of those jobs a second `needs` and a skip
starts being able to mean "an upstream job failed" instead.

A new job therefore needs two things, not one: an entry in `quality-gate`'s
`needs`, and — if it is specific to a package — an
`if: needs.affected.outputs.<package> == 'true'` condition. Repository-wide jobs
such as `analyze` stay ungated.
