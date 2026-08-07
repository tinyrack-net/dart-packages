# Tinyrack Dart packages

Reusable Dart libraries maintained by Tinyrack.

| Package | Description |
| --- | --- |
| [`cliweave`](packages/cliweave) | Typed command routing, help, completion, and terminal output for Dart CLIs. |
| [`dartage`](packages/dartage) | Pure-Dart age v1 encryption with native, passphrase, post-quantum, tag, and streaming support. |
| [`ptyworld`](packages/ptyworld) | Cross-platform pseudo-terminal processes built on `openpty` and ConPTY. |
| [`shipworld`](packages/shipworld) | Release, signing, and desktop-packaging tooling for Dart CLI and Flutter desktop apps. |

`cliweave`, `dartage`, and `shipworld` have independent versions and changelogs,
and are published to
[pub.dev](https://pub.dev/publishers/tinyrack.net/packages) by the verified
`tinyrack.net` publisher. Validate `shipworld` as a standalone package with
`dart run packages/shipworld/tool/validate_standalone.dart`.

`ptyworld` is unpublished (`publish_to: none`) while its public contract is
evaluated; consumers pin it by commit SHA. It is the only package here that
builds native code, through a `hook/build.dart` C native asset, so it needs no
prebuilt binary or manual build step.

## Development

Install the workspace dependencies from the repository root:

```console
dart pub get
```

Then validate the package you changed:

```console
cd packages/cliweave
dart format .
dart analyze --fatal-infos
dart test
```

Run the repository-owned coverage gate from the workspace root:

```console
dart run tool/verify_coverage.dart
```

Note that this form runs `shipworld`, which is only accurate on Windows; on
Linux, name the packages you want (for example
`dart run tool/verify_coverage.dart cliweave dartage ptyworld`).

This generates `coverage/<package>/lcov.info` and requires each package,
independently, to cover at least 95% of its executable `lib/` lines. The gate
uses the Dart test runner directly and does not require a globally installed
coverage tool.

`dartage` has an offline suite and a Node-backed interoperability suite:

```console
cd packages/dartage
dart test -x interop
cd test/interop
pnpm install --frozen-lockfile
cd ../..
dart test -t interop
```

`cliweave` also executes its generated completion scripts in the shells they
target. Install bash, zsh, and fish on Unix and PowerShell on Windows, then run:

```console
cd packages/cliweave
CLIWEAVE_E2E_SHELLS=bash,zsh,fish dart test -t e2e
```

On Windows PowerShell:

```powershell
$env:CLIWEAVE_E2E_SHELLS = 'powershell'
dart test -t e2e
```
