# shipworld

`shipworld` is a Dart library for preparing independently versioned releases
and packaging prebuilt Dart CLI and Flutter desktop payloads.

It supports:

- atomic multi-package release preparation and signed tag finalization;
- single-executable and directory payloads;
- Windows MSIX, macOS signing/archive, and Linux AppImage, deb, and rpm
  packaging;
- Homebrew Formula and Cask generation;
- strict schema-v1 configuration with editor-compatible JSON Schema;
- injected Git, process, environment, and logging boundaries.

The package is published to pub.dev from the `tinyrack-net/dart-packages`
workspace. It can also be moved to a standalone package repository; see the
[standalone repository handoff](doc/separation.md).

## Configuration

Projects declare independently versioned targets in `shipworld.yaml`:

```yaml
schema: 1
remote: origin
batch-commit: "release: {targets}"

targets:
  example:
    kind: pub-package
    root: packages/example
    version:
      source: pubspec.yaml
    changelog: CHANGELOG.md
    tag: "example-v{version}"
    commit: "release: example {version}"
    branch: main
```

Prepare a release commit, merge it through the repository's normal review
flow, then finalize its tag:

```console
dart run shipworld release prepare example=patch
dart run shipworld release finalize example --push
```

The release command validates every selected target before writing. Failed
version writes or commits restore generated files, and failed multi-tag
finalization removes tags created by the current invocation.

Desktop packaging uses the same target configuration:

```console
dart run shipworld package linux appimage example \
  --input build/linux/x64/release/bundle \
  --output dist/example.AppImage \
  --arch x86_64 \
  --tool /usr/local/bin/appimagetool
```

Homebrew Formula generation accepts `--versioned-output` when a tap publishes
both the current Formula and a `keg_only :versioned_formula` variant.

`homebrew.platforms` lists the `<platform>-<arch>` pairs a target builds,
defaulting to all four of `macos-arm64`, `macos-x64`, `linux-arm64`, and
`linux-x64`. Naming fewer omits the rest from the Formula instead of
referencing an artifact the release does not carry.

The Formula follows the target's `payload.kind`. An `executable` target reads
one bare file per platform, named `<artifact-prefix>-<platform>-<arch>`, and
installs it directly as the binary. A `directory` target reads
`<artifact-prefix>-<platform>-<arch>.tar.gz`, installs the unpacked bundle
into `libexec`, and symlinks the launcher into `bin`, which is what an
executable that loads sibling libraries at run time needs.

See [configuration](doc/configuration.md), the [CLI reference](doc/cli.md),
and the [standalone repository handoff](doc/separation.md).

## Library API

Load configuration and inject external boundaries once:

```dart
final config = await loadShipworldConfig('shipworld.yaml');
final context = ShipworldContext.io();
final releases = ReleaseService(config: config, context: context);

await releases.prepare(
  bumps: {'example': ReleaseType.patch},
  dryRun: true,
);
```

The public entrypoints are `shipworld.dart`, `release.dart`, `windows.dart`,
`macos.dart`, `linux.dart`, and `homebrew.dart`. Flutter is only needed to
build an application payload; it is not a Shipworld runtime dependency.
