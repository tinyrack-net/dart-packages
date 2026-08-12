# tinyrack_workspace

Reusable policy checks for repositories that consume Tinyrack-owned packages.
The package is intentionally distributed from the public Git repository at an
exact commit rather than published to pub.dev.

```sh
dart run tinyrack_workspace source-check --root=.
dart run tinyrack_workspace coverage-check --root=. --line=90 --branch=80
dart run tinyrack_workspace coverage-check --root=. --scope=app
```

`source-check` requires known Tinyrack dependencies to use their canonical
public Git repository, package path, and an immutable 40-character commit SHA.
It also requires a lockfile's `resolved-ref` to equal the declared ref.

`coverage-check` reads each selected package's `coverage/lcov.info`. Production
sources absent from LCOV count as uncovered; generated `.g.dart`,
`.freezed.dart`, and Flutter localization output are excluded.
