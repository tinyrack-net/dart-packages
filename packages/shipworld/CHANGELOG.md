# Changelog

## 0.2.4

- Generate a Homebrew Formula that matches the target's `payload.kind`. A
  `directory` target ships an executable plus the libraries it loads at run
  time, but the Formula still emitted `bin.install "<bare file>"`, which can
  only install a single file. Such a target now reads
  `<artifact-prefix>-<platform>-<arch>.tar.gz`, installs the unpacked bundle
  into `libexec`, and symlinks the launcher into `bin` — the executable's
  RPATH resolves against its real path, so the sibling libraries stay
  reachable through the link. An `executable` target is unchanged.

## 0.2.3

- Fixed the Cask `depends_on macos:` stanza to use the symbol form. Homebrew
  deprecated the string comparison, and the old form printed a warning on every
  `brew` invocation touching the tap.

## 0.2.2

- Fixed application-bundle signing to import the Developer ID certificate. The
  bundle path read `APPLE_DEVELOPER_ID` but never installed a keychain, so
  `codesign` reported `no identity found` for every Flutter desktop build that
  supplied a real certificate.
- Added notarization and stapling for application bundles, which previously
  signed and stopped. An un-stapled bundle is rejected by Gatekeeper offline.

## 0.2.1

- Fixed macOS application signing to sign nested Mach-O images and nested
  bundles instead of every file under `Frameworks`. A Flutter bundle keeps its
  assets inside `App.framework`, so the previous rule signed hundreds of
  images, one process each, and reported failures against a PNG.

## 0.2.0

- Added `package linux deb` and `package linux rpm`, which build distribution
  packages from a prebuilt payload using a caller-provided nfpm.
- Added optional `linux` maintainer, license, vendor, app id, prefix, launcher
  style, icon set, and per-format dependency configuration.
- Added optional `macos` bundle name, bundle id, and minimum version.
- **Breaking:** `generateHomebrewCask` now requires `bundleName`. The `app`
  stanza previously named the display name, so a cask whose bundle was named
  anything else installed nothing.
- Added optional Cask `zap`, `depends_on macos:`, and `livecheck` stanzas, and
  rejected tokens Homebrew would not accept.
- Fixed the AppImage icon to keep its source extension instead of forcing
  `.svg`.

## 0.1.2

- Verified automated pub.dev publishing from GitHub Actions using OIDC.

## 0.1.1

- Initial pub.dev release.

## 0.1.0

- Added schema-v1 typed configuration and its JSON Schema.
- Added atomic multi-target release preparation and signed-tag finalization.
- Added CLI commands for Windows, macOS, Linux, and Homebrew packaging.
- Added optional versioned Formula output to the Homebrew CLI.
- Added executable and directory payloads for Dart CLI and Flutter desktop.
- Added standalone package validation and public API documentation.
