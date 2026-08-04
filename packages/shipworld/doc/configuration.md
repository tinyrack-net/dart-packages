# Configuration

Shipworld reads `shipworld.yaml` from the current directory unless `--config`
selects another file. The configuration uses schema version 1. The canonical
machine-readable contract is
[`schema/shipworld.schema.json`](../schema/shipworld.schema.json).

```yaml
schema: 1
remote: origin
batch-commit: "release: {targets}"

targets:
  example:
    kind: flutter-application
    root: apps/example
    version:
      source: pubspec.yaml
      synchronized:
        - type: dart-constant
          path: lib/src/version.g.dart
          constant: packageVersion
    changelog: CHANGELOG.md
    tag: "example-v{version}"
    commit: "release: example {version}"
    branch: main
    payload:
      kind: directory
      launcher: Contents/MacOS/example
    product:
      name: example
      display-name: Example
      description: Example desktop application
      executable: example
      homepage: https://example.com
      repository: example/example
```

Paths are resolved inside the repository containing `shipworld.yaml`.
Version, changelog, synchronized writer, and payload launcher paths cannot
escape their configured boundary. Unknown fields and unsupported schema
versions are rejected before an operation starts.

`pub-package` and `cli-application` versions are bumped as normal semantic
versions. `flutter-application` also increments the numeric `+build` value.
The tag always receives the core version without build metadata.

## Linux packaging

`linux.icon`, `linux.categories`, and `linux.terminal` configure the AppImage
and are the only required keys. The rest are optional and are read by
`package linux deb` and `package linux rpm`:

```yaml
    linux:
      icon: assets/brand/example.svg
      categories: [Development]
      terminal: false
      maintainer: "Example <dev@example.com>"
      license: Apache-2.0          # required by rpm
      vendor: Example
      app-id: com.example.app      # defaults to product.name
      prefix: /usr/lib             # payload install directory
      launcher-style: symlink      # or wrapper
      icons:
        - { size: 128, path: assets/brand/example-128.png }
        - { size: 512, path: assets/brand/example-512.png }
      deb:
        depends: [libgtk-3-0t64, libayatana-appindicator3-1]
        section: devel
      rpm:
        requires: [gtk3, libayatana-appindicator-gtk3]
        release: "1"
        group: Applications/Productivity
```

The package installs the payload under `<prefix>/<product.name>`, links
`/usr/bin/<product.executable>` at the launcher, and writes a desktop entry and
the declared icons into the hicolor theme. Runtime dependencies are configured
rather than derived, because the same library is named differently by each
distribution.
