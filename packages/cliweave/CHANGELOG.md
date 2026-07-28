# Changelog

## 0.2.0

- Replace open `Map<String, Object?>` and `List<Object?>` command handlers with
  context-generic `FlagSet` and `PositionalSet` decoders. Handlers now receive
  closed records or user classes inferred from their declarations.
- Add typed direct and per-command context loading, context-aware parsing and
  completion, and type-preserving lazy command loaders.
- Port the Stricli 1.3 integration model: ordered validation and lifecycle
  hooks, root/global application flags, collision checks, help/version
  factories, integration error reporting, and completion visibility.
- Make an explicit integrations list replace the defaults; omitting it installs
  help, help-all, and configured version integrations.

## 0.1.1

- Patch release to verify automated pub.dev publishing from GitHub Actions
  using OIDC. There are no API or runtime behavior changes.

## 0.1.0

- Initial extraction from the dotweave CLI, where this code has been in
  production use.
- `package:cliweave/cliweave.dart`: command and route-map builders,
  flag and positional parameters, argument scanning with kebab/camel aliasing
  and did-you-mean suggestions, help rendering, structured exit codes, and
  completion proposals.
- `CompletionScripts` generates bash, zsh, fish, and PowerShell completion
  scripts for any executable name, and normalizes the tokens a shell hands
  back through `resolveCompletionInputs`.
- `package:cliweave/terminal.dart`: levelled logger, TTY-aware spinner, and
  a colour theme honouring `NO_COLOR`, `FORCE_COLOR`, and `CI`.
- Environment access goes through an injectable `EnvLookup` rather than a
  global, so consumers can supply their own view of the environment.

Initial public release. The API is expected to change before 1.0.
