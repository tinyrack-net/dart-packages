# Standalone repository handoff

The package is published to pub.dev from the `tinyrack-net/dart-packages`
workspace via the `shipworld-v*` tag trigger. To move it to a standalone
repository instead:

1. Copy `packages/shipworld` to the repository root.
2. Remove `resolution: workspace` from `pubspec.yaml`.
3. Add the repository CI and pub.dev OIDC publishing workflow, updating the
   tag pattern to the new repository's convention.
4. Run `dart run tool/validate_standalone.dart` and `pana --no-warning .`.
5. Transfer pub.dev automated-publishing trust to the new repository before the
   first tagged release from it.

No Dotweave source, asset, configuration, or test is required by the copied
package.
