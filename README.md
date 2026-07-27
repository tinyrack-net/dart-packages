# Tinyrack Dart packages

Reusable Dart libraries maintained by Tinyrack.

| Package | Description |
| --- | --- |
| [`cliweave`](packages/cliweave) | Typed command routing, help, completion, and terminal output for Dart CLIs. |
| [`dartage`](packages/dartage) | Pure-Dart age v1 encryption with X25519 recipients. |

Each package has an independent version and changelog. Releases are published
to [pub.dev](https://pub.dev/publishers/tinyrack.net/packages) by the verified
`tinyrack.net` publisher.

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

`dartage` has an offline suite and a Node-backed interoperability suite:

```console
cd packages/dartage
dart test -x interop
cd test/interop
pnpm install --frozen-lockfile
cd ../..
dart test -t interop
```
