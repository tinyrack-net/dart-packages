// Hand-rolled Dart port of the subset of `@stricli/core` (dist/index.js) that
// the dotweave CLI reaches. The TS CLI builds its command tree with stricli's
// `buildCommand`/`buildRouteMap`/`buildApplication` and runs it with `run` /
// `proposeCompletions`; no Dart package reproduces stricli's observable
// behavior (help text layout, error message templates, kebab⇄camel flag
// aliasing, did-you-mean suggestions, exit codes), so this module ports that
// behavior directly from the stricli source.
//
// Source references in comments point at sections of
// `packages/cli/node_modules/@stricli/core/dist/index.js`.
//
// Intentional deviations (unreached by the dotweave app configuration):
// - `customUsage` docs, route-map `defaultCommand` loaders from modules,
//   `versionInfo.getLatestVersion`/`upgradeCommand`, and context `forCommand`
//   loading are not ported (dotweave never configures them).
// - `shouldUseAnsiColor` approximates Node's `stream.getColorDepth() >= 4`
//   with `stream.isTTY` (plus the same `STRICLI_NO_COLOR` escape hatch).
// - `formatException` renders `toString()` instead of a JS stack trace; the
//   dotweave application overrides every formatter that reaches it except
//   `exceptionWhileParsingArguments`, which only formats scanner errors.

import 'dart:async';

import 'package:cliweave/src/env.dart';
import 'package:cliweave/src/write_stream.dart';

part 'router_help.dart';
part 'router_parse.dart';

/// Error thrown for invalid router configuration, mirroring stricli's
/// `InternalError` (src/util/error.ts).
class RouterInternalError implements Exception {
  /// Creates a [RouterInternalError].
  RouterInternalError(this.message);

  /// The human-readable message.
  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Context (stricli `CommandContext` / `ApplicationContext`)
// ---------------------------------------------------------------------------

/// Mirror of the `process` slice stricli requires from a run context:
/// stdout/stderr write streams, the environment, and a mutable exit code.
class RunProcess {
  /// Creates a [RunProcess].
  RunProcess({required this.stdout, required this.stderr, EnvLookup? readEnv})
    : readEnv = readEnv ?? lookupPlatformEnv;

  /// The stream used for standard output.
  final WriteStream stdout;

  /// The stream used for standard error.
  final WriteStream stderr;

  /// Environment lookup used for `STRICLI_NO_COLOR`. Supply one to read from
  /// somewhere other than the process environment.
  final EnvLookup readEnv;

  /// The exit code value.
  int? exitCode;
}

/// Mirror of stricli's `CommandContext`: the dotweave app only ever supplies
/// `process` (and never `locale` or `forCommand`).
class RunContext {
  /// Creates a [RunContext].
  RunContext({
    required this.process,
    this.locale,
    this.commandContext,
    this.forCommand,
  });

  /// The process-facing streams and environment.
  final RunProcess process;

  /// The locale requested for this run.
  final String? locale;

  /// Type-erased command context used by the public typed facade.
  Object? commandContext;

  /// Type-erased command-context loader used by the public typed facade.
  final FutureOr<Object> Function(List<String> prefix)? forCommand;
}

/// Documentation for an application-level flag supplied by an integration.
final class AdditionalFlagDocumentation {
  /// Creates additional flag documentation.
  const AdditionalFlagDocumentation({
    required this.name,
    required this.brief,
    this.aliases = const [],
    this.hidden = false,
    this.global = false,
    this.complete = false,
  });

  /// Long flag name without leading dashes.
  final String name;

  /// Description shown in help and completion.
  final String brief;

  /// Single-character aliases.
  final List<String> aliases;

  /// Whether normal help and completion hide this flag.
  final bool hidden;

  /// Whether the flag is available below the root target.
  final bool global;

  /// Whether completion includes this flag.
  final bool complete;
}

/// Application-level flag supplied by an integration.
final class InternalApplicationFlag {
  /// Creates an application-level flag.
  const InternalApplicationFlag({
    required this.documentation,
    required this.run,
    this.defaultForRouteMap = false,
  });

  /// Display and routing metadata.
  final AdditionalFlagDocumentation documentation;

  /// Whether this flag runs when a route map is selected without a flag.
  final bool defaultForRouteMap;

  /// Executes the application-level flag.
  final FutureOr<void> Function(
    RunContext context,
    Application app,
    IntegrationFlagArguments arguments,
  )
  run;
}

/// ANSI color decisions supplied to integration callbacks.
final class AnsiColorByStream {
  /// Creates stream color decisions.
  const AnsiColorByStream({required this.stdout, required this.stderr});

  /// Whether stdout supports color.
  final bool stdout;

  /// Whether stderr supports color.
  final bool stderr;
}

/// Base arguments supplied to lifecycle hooks.
final class ApplicationHookArguments {
  /// Creates application hook arguments.
  const ApplicationHookArguments({
    required this.text,
    required this.ansiColorByStream,
    this.exitCode,
  });

  /// Localized application text.
  final ApplicationText text;

  /// Color support by stream.
  final AnsiColorByStream ansiColorByStream;

  /// Intended exit code for end hooks.
  final int? exitCode;
}

/// Arguments supplied to command lifecycle hooks.
final class InternalCommandHookArguments extends ApplicationHookArguments {
  /// Creates command hook arguments.
  const InternalCommandHookArguments({
    required super.text,
    required super.ansiColorByStream,
    required this.result,
    super.exitCode,
  });

  /// Route scan result for the command.
  final RouteScanResult result;
}

/// Arguments supplied to an integration application flag.
final class IntegrationFlagArguments extends InternalCommandHookArguments {
  /// Creates integration flag arguments.
  const IntegrationFlagArguments({
    required super.text,
    required super.ansiColorByStream,
    required super.result,
    required this.additionalFlags,
  });

  /// Flags visible for the selected target.
  final List<AdditionalFlagDocumentation> additionalFlags;
}

/// Type-erased lifecycle hooks used by the typed facade.
final class InternalLifecycleHooks {
  /// Creates lifecycle hooks.
  const InternalLifecycleHooks({
    this.appStart,
    this.commandStart,
    this.commandEnd,
    this.appEnd,
  });

  /// Runs before route scanning.
  final FutureOr<void> Function(
    RunContext context,
    ApplicationHookArguments arguments,
  )?
  appStart;

  /// Runs before command parsing and execution.
  final FutureOr<void> Function(
    RunContext context,
    InternalCommandHookArguments arguments,
  )?
  commandStart;

  /// Runs after command execution.
  final FutureOr<void> Function(
    RunContext context,
    InternalCommandHookArguments arguments,
  )?
  commandEnd;

  /// Runs after route scanning or command execution.
  final FutureOr<void> Function(
    RunContext context,
    ApplicationHookArguments arguments,
  )?
  appEnd;
}

/// Type-erased integration used by the typed facade.
final class InternalIntegration {
  /// Creates an integration.
  const InternalIntegration({
    required this.name,
    this.validate,
    this.hooks,
    this.flag,
  });

  /// Integration name and application flag name.
  final String name;

  /// Application-build validation.
  final void Function(
    RoutingTarget root,
    ResolvedApplicationConfiguration configuration,
  )?
  validate;

  /// Lifecycle hooks.
  final InternalLifecycleHooks? hooks;

  /// Optional application flag.
  final InternalApplicationFlag? flag;
}

// ---------------------------------------------------------------------------
// Exit codes (src/exit-code.ts)
// ---------------------------------------------------------------------------

/// Mirror of stricli's `ExitCode` const object.
abstract final class ExitCode {
  /// An integration hook or application flag failed.
  static const int integrationError = -10;

  /// Unable to find a command in the application with the given inputs.
  static const int unknownCommand = -5;

  /// Unable to parse the specified arguments.
  static const int invalidArgument = -4;

  /// An error was thrown while loading the context for a command run.
  static const int contextLoadError = -3;

  /// Failed to load command module.
  static const int commandLoadError = -2;

  /// An unexpected error was thrown by or not caught by this library.
  static const int internalError = -1;

  /// Command executed successfully.
  static const int success = 0;

  /// Command module unexpectedly threw an error.
  static const int commandRunError = 1;
}

// ---------------------------------------------------------------------------
// Case styles
// ---------------------------------------------------------------------------

/// stricli scanner case styles ("original" | "allow-kebab-for-camel").
enum ScannerCaseStyle {
  /// Accepts flag names exactly as declared.
  original,

  /// Accepts kebab-case aliases for camel-case flag names.
  allowKebabForCamel,
}

/// stricli display case styles ("original" | "convert-camel-to-kebab").
enum DisplayCaseStyle {
  /// Displays names exactly as declared.
  original,

  /// Converts camel-case names to kebab case for display.
  convertCamelToKebab,
}

// ---------------------------------------------------------------------------
// Flag parameters (src/parameter/flag/types.ts)
// ---------------------------------------------------------------------------

/// Parse function for flag and positional inputs; the TS side uses arbitrary
/// `(this: Context, value: string) => T` functions (usually `String`).
typedef FlagParseFunction = FutureOr<Object?> Function(String input);

/// Completion callback for flags/positionals (`proposeCompletions` in TS).
typedef ProposeCompletionsCallback = FutureOr<List<String>> Function(
  String partial,
);

/// Internal context-aware parser used by the typed public facade.
typedef ContextualParseFunction = FutureOr<Object?> Function(
  RunContext context,
  String input,
);

/// Internal context-aware completion callback used by the typed public facade.
typedef ContextualProposeCompletionsCallback = FutureOr<List<String>> Function(
  RunContext context,
  String partial,
);

/// Identity parser mirroring the TS idiom `parse: String`.
String stringParser(String input) => input;

/// Base type for stricli flag parameters. [optional] is nullable to mirror
/// the TS `optional?: boolean` (unset falls back to "has a default value" in
/// `isOptionalAtRuntime`).
sealed class Flag {
  const Flag({required this.brief, this.optional, this.hidden = false});

  /// The short description shown in help output.
  final String brief;

  /// Whether the value can be omitted.
  final bool? optional;

  /// Whether the item is hidden from normal help output.
  final bool hidden;
}

/// stricli `kind: "boolean"` flag.
final class BooleanFlag extends Flag {
  /// Creates a [BooleanFlag].
  const BooleanFlag({
    required super.brief,
    super.optional,
    super.hidden,
    this.defaultValue,
    this.withNegated,
  });

  /// The value used when no input is provided.
  final bool? defaultValue;

  /// Mirrors `withNegated?: boolean`; only an explicit `false` disables the
  /// `--no-…` form (TS checks `withNegated !== false`).
  final bool? withNegated;
}

/// stricli `kind: "counter"` flag.
final class CounterFlag extends Flag {
  /// Creates a [CounterFlag].
  const CounterFlag({required super.brief, super.optional, super.hidden});
}

/// stricli `kind: "enum"` flag.
final class EnumFlag extends Flag {
  /// Creates an [EnumFlag].
  const EnumFlag({
    required super.brief,
    required this.values,
    super.optional,
    super.hidden,
    this.variadic = false,
    this.variadicSeparator,
    this.defaultValue,
    this.placeholder,
  });

  /// The accepted values.
  final List<String> values;

  /// Whether multiple input values are accepted.
  final bool variadic;

  /// Mirrors the TS `variadic: string` form (separator-joined inputs).
  final String? variadicSeparator;

  /// `String` or `List<String>` (variadic default).
  final Object? defaultValue;

  /// The placeholder shown for the value in help output.
  final String? placeholder;
}

/// stricli `kind: "parsed"` flag.
final class ParsedFlag extends Flag {
  /// Creates a [ParsedFlag].
  const ParsedFlag({
    required super.brief,
    required this.parse,
    super.optional,
    super.hidden,
    this.variadic = false,
    this.variadicSeparator,
    this.placeholder,
    this.defaultValue,
    this.inferEmpty = false,
    this.proposeCompletions,
    this.contextualParse,
    this.contextualProposeCompletions,
  });

  /// The parser used to convert the input value.
  final FlagParseFunction parse;

  /// Whether multiple input values are accepted.
  final bool variadic;

  /// Mirrors the TS `variadic: string` form (separator-joined inputs).
  final String? variadicSeparator;

  /// The placeholder shown for the value in help output.
  final String? placeholder;

  /// `String` or `List<String>` (variadic default); parsed like inputs.
  final Object? defaultValue;

  /// The infer empty value.
  final bool inferEmpty;

  /// The callback used to propose completions for partial input.
  final ProposeCompletionsCallback? proposeCompletions;

  /// Context-aware parser used by the typed facade.
  final ContextualParseFunction? contextualParse;

  /// Context-aware completion callback used by the typed facade.
  final ContextualProposeCompletionsCallback? contextualProposeCompletions;
}

// ---------------------------------------------------------------------------
// Positional parameters (src/parameter/positional/types.ts)
// ---------------------------------------------------------------------------

/// A single positional parameter definition.
final class PositionalParameter {
  /// Creates a [PositionalParameter].
  const PositionalParameter({
    required this.brief,
    required this.parse,
    this.placeholder,
    this.defaultValue,
    this.optional,
    this.proposeCompletions,
    this.contextualParse,
    this.contextualProposeCompletions,
  });

  /// The short description shown in help output.
  final String brief;

  /// The parser used to convert the input value.
  final FlagParseFunction parse;

  /// The placeholder shown for the value in help output.
  final String? placeholder;

  /// The value used when no input is provided.
  final String? defaultValue;

  /// Whether the value can be omitted.
  final bool? optional;

  /// The callback used to propose completions for partial input.
  final ProposeCompletionsCallback? proposeCompletions;

  /// Context-aware parser used by the typed facade.
  final ContextualParseFunction? contextualParse;

  /// Context-aware completion callback used by the typed facade.
  final ContextualProposeCompletionsCallback? contextualProposeCompletions;
}

/// Positional parameter layout (`kind: "tuple" | "array"` in TS).
sealed class PositionalParameters {
  const PositionalParameters();
}

/// stricli `positional: { kind: "tuple", parameters: [...] }`.
final class TuplePositionalParameters extends PositionalParameters {
  /// Creates a [TuplePositionalParameters].
  const TuplePositionalParameters(this.parameters);

  /// The command parameter definitions.
  final List<PositionalParameter> parameters;
}

/// stricli `positional: { kind: "array", parameter, minimum?, maximum? }`.
final class ArrayPositionalParameters extends PositionalParameters {
  /// Creates an [ArrayPositionalParameters].
  const ArrayPositionalParameters({
    required this.parameter,
    this.minimum,
    this.maximum,
  });

  /// The parameter value.
  final PositionalParameter parameter;

  /// The minimum number of accepted values.
  final int? minimum;

  /// The maximum number of accepted values.
  final int? maximum;
}

// ---------------------------------------------------------------------------
// Command (src/routing/command)
// ---------------------------------------------------------------------------

/// Mirror of stricli `CommandParameters`: flags keyed by internal (camelCase)
/// name, single-letter aliases, and the positional layout.
final class CommandParameters {
  /// Creates a [CommandParameters].
  const CommandParameters({
    this.flags = const {},
    this.aliases = const {},
    this.positional,
  });

  /// The flags keyed by their internal names.
  final Map<String, Flag> flags;

  /// The alternative names accepted for the item.
  final Map<String, String> aliases;

  /// The positional parameter layout.
  final PositionalParameters? positional;
}

/// Mirror of stricli `CommandDocumentation` (`customUsage` is not ported).
final class CommandDocs {
  /// Creates a [CommandDocs].
  const CommandDocs({required this.brief, this.fullDescription});

  /// The short description shown in help output.
  final String brief;

  /// The optional long-form description shown in detailed help.
  final String? fullDescription;
}

/// Command implementation signature. stricli calls
/// `func.call(context, flags, ...positional)`; the Dart port passes the
/// context explicitly and the positional values as a list. A returned
/// [Error]/[Exception] is reported through `commandErrorResult`, mirroring
/// the TS `result instanceof Error` check.
typedef CommandFunction = FutureOr<Object?> Function(
  RunContext context,
  Map<String, Object?> flags,
  List<Object?> positional,
);

/// Mirror of stricli's `loader` indirection (`command.loader()` resolves the
/// function to run); the ported `commands.test.ts` invokes this directly.
typedef CommandLoader = FutureOr<CommandFunction> Function();

/// A routing tree node: either a [Command] or a [RouteMap].
sealed class RoutingTarget {
  /// The short description shown in help output.
  String get brief;

  /// The optional long-form description shown in detailed help.
  String? get fullDescription;

  /// Formats this target's usage line.
  String formatUsageLine(HelpFormattingArguments args);

  /// Formats the complete help text for this target.
  String formatHelp(HelpFormattingArguments args);
}

/// Mirror of a built stricli command.
final class Command extends RoutingTarget {
  Command._(this.loader, this.parameters, this._docs);

  /// The loader value.
  final CommandLoader loader;

  /// The command parameter definitions.
  final CommandParameters parameters;
  final CommandDocs _docs;

  @override
  String get brief => _docs.brief;

  @override
  String? get fullDescription => _docs.fullDescription;

  @override
  String formatUsageLine(HelpFormattingArguments args) {
    return _formatUsageLineForParameters(parameters, args);
  }

  @override
  String formatHelp(HelpFormattingArguments args) {
    final lines = _generateCommandHelpLines(parameters, _docs, args).toList();
    return '${lines.join('\n')}\n';
  }

  /// Mirror of `usesFlag` (checked when a command is the application root).
  bool usesFlag(String flagName) {
    return parameters.flags.containsKey(flagName) ||
        parameters.aliases.containsKey(flagName);
  }
}

/// Mirror of stricli `buildCommand` (src/routing/command/builder.ts).
Command buildCommand({
  required CommandDocs docs,
  required CommandFunction func,
  required CommandParameters parameters,
}) {
  final flags = parameters.flags;
  _checkForNegationCollisions(flags);
  _checkForInvalidVariadicSeparators(flags);
  return Command._(() => func, parameters, docs);
}

/// Internal lazy-command builder used by the typed public facade.
Command buildLazyCommand({
  required CommandDocs docs,
  required CommandLoader loader,
  required CommandParameters parameters,
}) {
  final flags = parameters.flags;
  _checkForNegationCollisions(flags);
  _checkForInvalidVariadicSeparators(flags);
  return Command._(loader, parameters, docs);
}

// ---------------------------------------------------------------------------
// Route maps (src/routing/route-map)
// ---------------------------------------------------------------------------

/// Mirror of stricli `RouteMapDocumentation`.
final class RouteMapDocs {
  /// Creates a [RouteMapDocs].
  const RouteMapDocs({
    required this.brief,
    this.fullDescription,
    this.hideRoute = const {},
  });

  /// The short description shown in help output.
  final String brief;

  /// The optional long-form description shown in detailed help.
  final String? fullDescription;

  /// The hide route value.
  final Map<String, bool> hideRoute;
}

/// Route name in both display case styles.
final class RouteName {
  /// Creates a [RouteName].
  const RouteName({required this.original, required this.convertCamelToKebab});

  /// The name in its original case style.
  final String original;

  /// The name converted from camel case to kebab case.
  final String convertCamelToKebab;

  /// Returns the route name rendered in [style].
  String byStyle(DisplayCaseStyle style) {
    return style == DisplayCaseStyle.convertCamelToKebab
        ? convertCamelToKebab
        : original;
  }
}

/// Mirror of an entry returned by stricli's `RouteMap#getAllEntries`.
final class RouteMapEntry {
  /// Creates a [RouteMapEntry].
  const RouteMapEntry({
    required this.name,
    required this.target,
    required this.aliases,
    required this.hidden,
  });

  /// The name of the item.
  final RouteName name;

  /// The routing target for the entry.
  final RoutingTarget target;

  /// The alternative names accepted for the item.
  final List<String> aliases;

  /// Whether the item is hidden from normal help output.
  final bool hidden;
}

/// Aliases of a scanned route in both display case styles (mirror of the
/// object returned by `getOtherAliasesForInput`).
final class RouteNameAliases {
  /// Creates a [RouteNameAliases].
  const RouteNameAliases({
    required this.original,
    required this.convertCamelToKebab,
  });

  /// Creates an alias collection with no aliases.
  const RouteNameAliases.empty()
    : original = const [],
      convertCamelToKebab = const [];

  /// The name in its original case style.
  final List<String> original;

  /// The name converted from camel case to kebab case.
  final List<String> convertCamelToKebab;

  /// Returns the aliases rendered in [style].
  List<String> byStyle(DisplayCaseStyle style) {
    return style == DisplayCaseStyle.convertCamelToKebab
        ? convertCamelToKebab
        : original;
  }
}

/// Mirror of a built stricli route map.
final class RouteMap extends RoutingTarget {
  RouteMap._(
    this._routes,
    this._docs,
    this._aliases,
    this._aliasesByRoute,
    this._defaultCommandRoute,
  );

  final Map<String, RoutingTarget> _routes;
  final RouteMapDocs _docs;
  final Map<String, String> _aliases;
  final Map<String, List<String>> _aliasesByRoute;
  final String? _defaultCommandRoute;

  @override
  String get brief => _docs.brief;

  @override
  String? get fullDescription => _docs.fullDescription;

  @override
  String formatUsageLine(HelpFormattingArguments args) {
    final routeNames = getAllEntries()
        .where((entry) => !entry.hidden)
        .map((entry) => entry.name.byStyle(args.config.caseStyle));
    return '${args.prefix.join(' ')} ${routeNames.join('|')} ...';
  }

  @override
  String formatHelp(HelpFormattingArguments args) {
    final lines = _generateRouteMapHelpLines(_routes, _docs, args).toList();
    return '${lines.join('\n')}\n';
  }

  /// Returns the default command, if one is configured.
  Command? getDefaultCommand() {
    final route = _defaultCommandRoute;
    if (route == null) {
      return null;
    }
    final target = _routes[route];
    return target is Command ? target : null;
  }

  String? _resolveRouteName(String input) {
    if (_aliases.containsKey(input)) {
      return _aliases[input];
    }
    if (_routes.containsKey(input)) {
      return input;
    }
    return null;
  }

  /// Mirror of `getOtherAliasesForInput` (dist index.js:2164).
  RouteNameAliases getOtherAliasesForInput(
    String input,
    ScannerCaseStyle caseStyle,
  ) {
    final defaultCommandRoute = _defaultCommandRoute;
    if (defaultCommandRoute != null) {
      if (input == defaultCommandRoute) {
        return const RouteNameAliases(
          original: [''],
          convertCamelToKebab: [''],
        );
      }
      if (input == '') {
        return RouteNameAliases(
          original: [defaultCommandRoute],
          convertCamelToKebab: [defaultCommandRoute],
        );
      }
    }
    final camelInput = convertKebabCaseToCamelCase(input);
    var routeName = _resolveRouteName(input);
    if (routeName == null && caseStyle == ScannerCaseStyle.allowKebabForCamel) {
      routeName = _resolveRouteName(camelInput);
    }
    if (routeName == null) {
      return const RouteNameAliases.empty();
    }
    final otherAliases = [
      routeName,
      ...?_aliasesByRoute[routeName],
    ].where((alias) => alias != input && alias != camelInput).toList();
    return RouteNameAliases(
      original: otherAliases,
      convertCamelToKebab: otherAliases
          .map(convertCamelCaseToKebabCase)
          .toList(),
    );
  }

  /// Resolves [input] to a route target.
  RoutingTarget? getRoutingTargetForInput(String input) {
    final routeName = _aliases[input] ?? input;
    return _routes[routeName];
  }

  /// Returns every route entry in declaration order.
  List<RouteMapEntry> getAllEntries() {
    return _routes.entries.map((entry) {
      return RouteMapEntry(
        name: RouteName(
          original: entry.key,
          convertCamelToKebab: convertCamelCaseToKebabCase(entry.key),
        ),
        target: entry.value,
        aliases: _aliasesByRoute[entry.key] ?? const [],
        hidden: _docs.hideRoute[entry.key] ?? false,
      );
    }).toList();
  }
}

/// Mirror of stricli `buildRouteMap` (src/routing/route-map/builder.ts).
RouteMap buildRouteMap({
  required RouteMapDocs docs,
  required Map<String, RoutingTarget> routes,
  String? defaultCommand,
  Map<String, String> aliases = const {},
}) {
  if (routes.isEmpty) {
    throw RouterInternalError('Route map must contain at least one route');
  }
  final aliasesByRoute = <String, List<String>>{};
  for (final entry in aliases.entries) {
    if (routes.containsKey(entry.key)) {
      throw RouterInternalError(
        'Cannot use "${entry.key}" as an alias when a route with that name already exists',
      );
    }
    aliasesByRoute.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  final defaultCommandTarget = defaultCommand == null
      ? null
      : routes[defaultCommand];
  if (defaultCommandTarget is RouteMap) {
    throw RouterInternalError(
      'Cannot use "$defaultCommand" as the default command because it is not a Command',
    );
  }
  return RouteMap._(routes, docs, aliases, aliasesByRoute, defaultCommand);
}

// ---------------------------------------------------------------------------
// Application text (src/text.ts)
// ---------------------------------------------------------------------------

/// Section headers used by help rendering.
final class TextHeaders {
  /// Creates a [TextHeaders].
  const TextHeaders({
    required this.usage,
    required this.aliases,
    required this.commands,
    required this.flags,
    required this.arguments,
  });

  /// The usage value.
  final String usage;

  /// The alternative names accepted for the item.
  final String aliases;

  /// The commands value.
  final String commands;

  /// The flags keyed by their internal names.
  final String flags;

  /// The arguments value.
  final String arguments;
}

/// Keywords used by help rendering (`default =`, `separator =`).
final class TextKeywords {
  /// Creates a [TextKeywords].
  const TextKeywords({required this.defaultKeyword, required this.separator});

  /// The default keyword value.
  final String defaultKeyword;

  /// The separator value.
  final String separator;
}

/// Briefs for the built-in flags.
final class TextBriefs {
  /// Creates a [TextBriefs].
  const TextBriefs({
    required this.help,
    required this.helpAll,
    required this.version,
    required this.argumentEscapeSequence,
  });

  /// The help value.
  final String help;

  /// The help all value.
  final String helpAll;

  /// The version value.
  final String version;

  /// The argument escape sequence value.
  final String argumentEscapeSequence;
}

/// Arguments for `noCommandRegisteredForInput`.
final class NoCommandRegisteredArguments {
  /// Creates a [NoCommandRegisteredArguments].
  const NoCommandRegisteredArguments({
    required this.input,
    required this.corrections,
    required this.ansiColor,
  });

  /// The input value.
  final String input;

  /// Suggested corrections for invalid input.
  final List<String> corrections;

  /// Whether ANSI color sequences are enabled.
  final bool ansiColor;
}

/// Arguments for `noTextAvailableForLocale`.
final class NoTextAvailableArguments {
  /// Creates a [NoTextAvailableArguments].
  const NoTextAvailableArguments({
    required this.requestedLocale,
    required this.defaultLocale,
    required this.ansiColor,
  });

  /// The requested locale.
  final String requestedLocale;

  /// The fallback locale.
  final String defaultLocale;

  /// Whether ANSI color sequences are enabled.
  final bool ansiColor;
}

/// Arguments for `currentVersionIsNotLatest`.
final class CurrentVersionNotLatestArguments {
  /// Creates a [CurrentVersionNotLatestArguments].
  const CurrentVersionNotLatestArguments({
    required this.currentVersion,
    required this.latestVersion,
    this.upgradeCommand,
  });

  /// The current application version.
  final String currentVersion;

  /// The latest version value.
  final String latestVersion;

  /// The upgrade command value.
  final String? upgradeCommand;
}

/// Arguments for an integration hook failure message.
final class IntegrationHookErrorArguments {
  /// Creates integration hook error arguments.
  const IntegrationHookErrorArguments({
    required this.exception,
    required this.hook,
    required this.integration,
    required this.ansiColor,
  });

  /// Thrown value.
  final Object exception;

  /// Hook name.
  final String hook;

  /// Integration name.
  final String integration;

  /// Whether ANSI color is enabled.
  final bool ansiColor;
}

/// Arguments for an integration flag failure message.
final class IntegrationFlagErrorArguments {
  /// Creates integration flag error arguments.
  const IntegrationFlagErrorArguments({
    required this.exception,
    required this.integration,
    required this.ansiColor,
  });

  /// Thrown value.
  final Object exception;

  /// Integration name.
  final String integration;

  /// Whether ANSI color is enabled.
  final bool ansiColor;
}

String _defaultIntegrationHookError(IntegrationHookErrorArguments args) {
  return 'Integration "${args.integration}" failed during ${args.hook}, '
      '${_formatException(args.exception)}';
}

String _defaultIntegrationFlagError(IntegrationFlagErrorArguments args) {
  return 'Unable to run integration flag "--${args.integration}", '
      '${_formatException(args.exception)}';
}

/// Mirror of stricli `ApplicationText`; the dotweave app overrides the error
/// formatters via [copyWith] (TS spreads over `text_en`).
final class ApplicationText {
  /// Creates an [ApplicationText].
  const ApplicationText({
    required this.headers,
    required this.keywords,
    required this.briefs,
    required this.noCommandRegisteredForInput,
    required this.noTextAvailableForLocale,
    required this.exceptionWhileParsingArguments,
    required this.exceptionWhileLoadingCommandFunction,
    required this.exceptionWhileLoadingCommandContext,
    required this.exceptionWhileRunningCommand,
    required this.commandErrorResult,
    required this.currentVersionIsNotLatest,
    this.exceptionWhileRunningIntegrationHook = _defaultIntegrationHookError,
    this.exceptionWhileRunningIntegrationFlag = _defaultIntegrationFlagError,
  });

  /// The headers value.
  final TextHeaders headers;

  /// The keywords value.
  final TextKeywords keywords;

  /// The briefs value.
  final TextBriefs briefs;

  /// Formats an unknown-command error.
  final String Function(NoCommandRegisteredArguments args)
  noCommandRegisteredForInput;

  /// Formats an unavailable-locale error.
  final String Function(NoTextAvailableArguments args) noTextAvailableForLocale;

  /// Formats an argument-parsing exception.
  final String Function(Object exc, bool ansiColor)
  exceptionWhileParsingArguments;

  /// Formats a command-function loading exception.
  final String Function(Object exc, bool ansiColor)
  exceptionWhileLoadingCommandFunction;

  /// Formats a command-context loading exception.
  final String Function(Object exc, bool ansiColor)
  exceptionWhileLoadingCommandContext;

  /// Formats a command execution exception.
  final String Function(Object exc, bool ansiColor)
  exceptionWhileRunningCommand;

  /// Formats an error returned by a command.
  final String Function(Object error, bool ansiColor) commandErrorResult;

  /// Formats an available-version update notice.
  final String Function(CurrentVersionNotLatestArguments args)
  currentVersionIsNotLatest;

  /// Formats an integration lifecycle hook exception.
  final String Function(IntegrationHookErrorArguments args)
  exceptionWhileRunningIntegrationHook;

  /// Formats an integration application flag exception.
  final String Function(IntegrationFlagErrorArguments args)
  exceptionWhileRunningIntegrationFlag;

  /// Returns a copy with the supplied text overrides.
  ApplicationText copyWith({
    TextHeaders? headers,
    TextKeywords? keywords,
    TextBriefs? briefs,
    String Function(NoCommandRegisteredArguments args)?
    noCommandRegisteredForInput,
    String Function(NoTextAvailableArguments args)? noTextAvailableForLocale,
    String Function(Object exc, bool ansiColor)? exceptionWhileParsingArguments,
    String Function(Object exc, bool ansiColor)?
    exceptionWhileLoadingCommandFunction,
    String Function(Object exc, bool ansiColor)?
    exceptionWhileLoadingCommandContext,
    String Function(Object exc, bool ansiColor)? exceptionWhileRunningCommand,
    String Function(Object error, bool ansiColor)? commandErrorResult,
    String Function(CurrentVersionNotLatestArguments args)?
    currentVersionIsNotLatest,
    String Function(IntegrationHookErrorArguments args)?
    exceptionWhileRunningIntegrationHook,
    String Function(IntegrationFlagErrorArguments args)?
    exceptionWhileRunningIntegrationFlag,
  }) {
    return ApplicationText(
      headers: headers ?? this.headers,
      keywords: keywords ?? this.keywords,
      briefs: briefs ?? this.briefs,
      noCommandRegisteredForInput:
          noCommandRegisteredForInput ?? this.noCommandRegisteredForInput,
      noTextAvailableForLocale:
          noTextAvailableForLocale ?? this.noTextAvailableForLocale,
      exceptionWhileParsingArguments:
          exceptionWhileParsingArguments ?? this.exceptionWhileParsingArguments,
      exceptionWhileLoadingCommandFunction:
          exceptionWhileLoadingCommandFunction ??
          this.exceptionWhileLoadingCommandFunction,
      exceptionWhileLoadingCommandContext:
          exceptionWhileLoadingCommandContext ??
          this.exceptionWhileLoadingCommandContext,
      exceptionWhileRunningCommand:
          exceptionWhileRunningCommand ?? this.exceptionWhileRunningCommand,
      commandErrorResult: commandErrorResult ?? this.commandErrorResult,
      currentVersionIsNotLatest:
          currentVersionIsNotLatest ?? this.currentVersionIsNotLatest,
      exceptionWhileRunningIntegrationHook:
          exceptionWhileRunningIntegrationHook ??
          this.exceptionWhileRunningIntegrationHook,
      exceptionWhileRunningIntegrationFlag:
          exceptionWhileRunningIntegrationFlag ??
          this.exceptionWhileRunningIntegrationFlag,
    );
  }
}

/// Mirror of stricli `text_en` (dist index.js:1068).
final ApplicationText textEn = ApplicationText(
  headers: const TextHeaders(
    usage: 'USAGE',
    aliases: 'ALIASES',
    commands: 'COMMANDS',
    flags: 'FLAGS',
    arguments: 'ARGUMENTS',
  ),
  keywords: const TextKeywords(
    defaultKeyword: 'default =',
    separator: 'separator =',
  ),
  briefs: const TextBriefs(
    help: 'Print help information and exit',
    helpAll:
        'Print help information (including hidden commands/flags) and exit',
    version: 'Print version information and exit',
    argumentEscapeSequence:
        'All subsequent inputs should be interpreted as arguments',
  ),
  noCommandRegisteredForInput: (args) {
    final errorMessage = 'No command registered for `${args.input}`';
    if (args.corrections.isNotEmpty) {
      final formattedCorrections = joinWithGrammar(
        args.corrections,
        conjunction: 'or',
        serialComma: true,
      );
      return '$errorMessage, did you mean $formattedCorrections?';
    }
    return errorMessage;
  },
  noTextAvailableForLocale: (args) {
    return 'Application does not support "${args.requestedLocale}" locale, '
        'defaulting to "${args.defaultLocale}"';
  },
  exceptionWhileParsingArguments: (exc, ansiColor) {
    if (exc is ArgumentScannerError) {
      return formatMessageForArgumentScannerError(exc, const {});
    }
    return 'Unable to parse arguments, ${_formatException(exc)}';
  },
  exceptionWhileLoadingCommandFunction: (exc, ansiColor) {
    return 'Unable to load command function, ${_formatException(exc)}';
  },
  exceptionWhileLoadingCommandContext: (exc, ansiColor) {
    return 'Unable to load command context, ${_formatException(exc)}';
  },
  exceptionWhileRunningCommand: (exc, ansiColor) {
    return 'Command failed, ${_formatException(exc)}';
  },
  commandErrorResult: (error, ansiColor) => _thrownMessage(error),
  currentVersionIsNotLatest: (args) {
    if (args.upgradeCommand != null) {
      return 'Latest available version is ${args.latestVersion} '
          '(currently running ${args.currentVersion}), upgrade with '
          '"${args.upgradeCommand}"';
    }
    return 'Latest available version is ${args.latestVersion} '
        '(currently running ${args.currentVersion})';
  },
);

/// Mirror of `formatException`; Dart exceptions carry no `.stack`, so this
/// renders `toString()`.
String _formatException(Object exc) => exc.toString();

// ---------------------------------------------------------------------------
// Configuration (src/config.ts)
// ---------------------------------------------------------------------------

/// Damerau-Levenshtein weights (`distanceOptions.weights`).
final class DistanceWeights {
  /// Creates a [DistanceWeights].
  const DistanceWeights({
    required this.insertion,
    required this.deletion,
    required this.substitution,
    required this.transposition,
  });

  /// The insertion value.
  final num insertion;

  /// The deletion value.
  final num deletion;

  /// The substitution value.
  final num substitution;

  /// The cost assigned to transposed characters.
  final num transposition;
}

/// Damerau-Levenshtein options used for did-you-mean suggestions.
final class DistanceOptions {
  /// Creates a [DistanceOptions].
  const DistanceOptions({required this.threshold, required this.weights});

  /// The maximum distance accepted for a correction.
  final num threshold;

  /// The weights value.
  final DistanceWeights weights;
}

/// stricli's default distance options (dist index.js:1469).
const DistanceOptions defaultDistanceOptions = DistanceOptions(
  threshold: 7,
  weights: DistanceWeights(
    insertion: 1,
    deletion: 3,
    substitution: 2,
    transposition: 0,
  ),
);

/// Input scanner configuration (all fields optional, like TS).
final class ScannerConfiguration {
  /// Creates a [ScannerConfiguration].
  const ScannerConfiguration({
    this.caseStyle,
    this.allowArgumentEscapeSequence,
    this.distanceOptions,
  });

  /// The case style used while scanning names.
  final ScannerCaseStyle? caseStyle;

  /// Whether the argument escape sequence is accepted.
  final bool? allowArgumentEscapeSequence;

  /// The distance options value.
  final DistanceOptions? distanceOptions;
}

/// Input documentation configuration (all fields optional, like TS).
final class DocumentationConfiguration {
  /// Creates a [DocumentationConfiguration].
  const DocumentationConfiguration({
    this.alwaysShowHelpAllFlag,
    this.useAliasInUsageLine,
    this.onlyRequiredInUsageLine,
    this.caseStyle,
    this.disableAnsiColor,
  });

  /// Whether the help-all flag is always displayed.
  final bool? alwaysShowHelpAllFlag;

  /// Whether usage lines may display an alias.
  final bool? useAliasInUsageLine;

  /// Whether usage lines show only required parameters.
  final bool? onlyRequiredInUsageLine;

  /// The case style used while scanning names.
  final DisplayCaseStyle? caseStyle;

  /// Whether ANSI color output is disabled.
  final bool? disableAnsiColor;
}

/// Input completion configuration (all fields optional, like TS).
final class CompletionConfiguration {
  /// Creates a [CompletionConfiguration].
  const CompletionConfiguration({
    this.includeAliases,
    this.includeHiddenRoutes,
    this.includeHiddenFlags,
  });

  /// Whether aliases are included in rendered help.
  final bool? includeAliases;

  /// Whether hidden routes are included.
  final bool? includeHiddenRoutes;

  /// Whether hidden flags are proposed.
  ///
  /// Defaults to false, matching help output. A flag is usually hidden
  /// because naming it would encourage a use its owner does not want, such as
  /// passing a secret on the command line, and a completion proposal is as
  /// much of an invitation as a help entry.
  final bool? includeHiddenFlags;
}

/// Localization configuration; dotweave supplies `defaultLocale` + `loadText`.
final class LocalizationConfiguration {
  /// Creates a [LocalizationConfiguration].
  const LocalizationConfiguration({
    this.defaultLocale,
    this.loadText,
    this.text,
  });

  /// The fallback locale.
  final String? defaultLocale;

  /// Loads localized application text.
  final ApplicationText? Function(String locale)? loadText;

  /// The localized application text.
  final ApplicationText? text;
}

/// Version metadata used by the default version integration.
final class VersionInformation {
  /// Creates a [VersionInformation].
  const VersionInformation({
    this.currentVersion,
    this.getCurrentVersion,
    this.getLatestVersion,
    this.upgradeCommand,
  }) : assert(
         (currentVersion == null) != (getCurrentVersion == null),
         'Provide exactly one current-version source',
       );

  /// A static current application version.
  final String? currentVersion;

  /// Asynchronously resolves the current application version.
  final FutureOr<String> Function(RunContext context)? getCurrentVersion;

  /// Resolves the latest available version from the current version.
  final FutureOr<String?> Function(RunContext context, String currentVersion)?
  getLatestVersion;

  /// Optional command displayed in update notices.
  final String? upgradeCommand;

  /// Resolves the configured current version.
  Future<String> resolveCurrent(RunContext context) async =>
      currentVersion ?? await getCurrentVersion!(context);
}

/// Mirror of the stricli application configuration object.
final class ApplicationConfiguration {
  /// Creates an [ApplicationConfiguration].
  const ApplicationConfiguration({
    required this.name,
    this.completion,
    this.determineExitCode,
    this.documentation,
    this.localization,
    this.scanner,
    this.versionInfo,
  });

  /// The name of the item.
  final String name;

  /// The proposed completion value.
  final CompletionConfiguration? completion;

  /// Determines the exit code for an error.
  final int Function(Object? error)? determineExitCode;

  /// The documentation associated with the target.
  final DocumentationConfiguration? documentation;

  /// The localization configuration.
  final LocalizationConfiguration? localization;

  /// The scanner state for the parsed arguments.
  final ScannerConfiguration? scanner;

  /// The optional application version metadata.
  final VersionInformation? versionInfo;
}

/// Resolved scanner configuration after `withDefaults`.
final class ScannerConfig {
  /// Creates a [ScannerConfig].
  const ScannerConfig({
    required this.caseStyle,
    required this.allowArgumentEscapeSequence,
    required this.distanceOptions,
  });

  /// The case style used while scanning names.
  final ScannerCaseStyle caseStyle;

  /// Whether the argument escape sequence is accepted.
  final bool allowArgumentEscapeSequence;

  /// The distance options value.
  final DistanceOptions distanceOptions;
}

/// Resolved documentation configuration after `withDefaults`.
final class DocumentationConfig {
  /// Creates a [DocumentationConfig].
  const DocumentationConfig({
    required this.alwaysShowHelpAllFlag,
    required this.useAliasInUsageLine,
    required this.onlyRequiredInUsageLine,
    required this.caseStyle,
    required this.disableAnsiColor,
  });

  /// Whether the help-all flag is always displayed.
  final bool alwaysShowHelpAllFlag;

  /// Whether usage lines may display an alias.
  final bool useAliasInUsageLine;

  /// Whether usage lines show only required parameters.
  final bool onlyRequiredInUsageLine;

  /// The case style used while scanning names.
  final DisplayCaseStyle caseStyle;

  /// Whether ANSI color output is disabled.
  final bool disableAnsiColor;
}

/// Resolved completion configuration after `withDefaults`.
final class CompletionConfig {
  /// Creates a [CompletionConfig].
  const CompletionConfig({
    required this.includeAliases,
    required this.includeHiddenRoutes,
    required this.includeHiddenFlags,
  });

  /// Whether aliases are included in rendered help.
  final bool includeAliases;

  /// Whether hidden routes are included.
  final bool includeHiddenRoutes;

  /// Whether hidden flags are proposed.
  final bool includeHiddenFlags;
}

/// Resolved localization configuration after `withDefaults`.
final class LocalizationConfig {
  /// Creates a [LocalizationConfig].
  const LocalizationConfig({
    required this.defaultLocale,
    this.loadText,
    this.text,
  });

  /// The fallback locale.
  final String defaultLocale;

  /// Loads localized application text.
  final ApplicationText? Function(String locale)? loadText;

  /// The localized application text.
  final ApplicationText? text;
}

/// Full resolved application configuration (mirror of `withDefaults` output).
final class ResolvedApplicationConfiguration {
  /// Creates a [ResolvedApplicationConfiguration].
  const ResolvedApplicationConfiguration({
    required this.name,
    required this.scanner,
    required this.completion,
    required this.documentation,
    required this.localization,
    this.determineExitCode,
    this.versionInfo,
  });

  /// The name of the item.
  final String name;

  /// The scanner state for the parsed arguments.
  final ScannerConfig scanner;

  /// The proposed completion value.
  final CompletionConfig completion;

  /// The documentation associated with the target.
  final DocumentationConfig documentation;

  /// The localization configuration.
  final LocalizationConfig localization;

  /// Determines the exit code for an error.
  final int Function(Object? error)? determineExitCode;

  /// The optional application version metadata.
  final VersionInformation? versionInfo;
}

/// Mirror of stricli `withDefaults` (dist index.js:1453).
ResolvedApplicationConfiguration _withDefaults(
  ApplicationConfiguration config,
) {
  final scannerCaseStyle =
      config.scanner?.caseStyle ?? ScannerCaseStyle.original;
  DisplayCaseStyle displayCaseStyle;
  final documentationCaseStyle = config.documentation?.caseStyle;
  if (documentationCaseStyle != null) {
    if (scannerCaseStyle == ScannerCaseStyle.original &&
        documentationCaseStyle == DisplayCaseStyle.convertCamelToKebab) {
      throw RouterInternalError(
        'Cannot convert route and flag names on display but scan as original',
      );
    }
    displayCaseStyle = documentationCaseStyle;
  } else if (scannerCaseStyle == ScannerCaseStyle.allowKebabForCamel) {
    displayCaseStyle = DisplayCaseStyle.convertCamelToKebab;
  } else {
    displayCaseStyle = DisplayCaseStyle.original;
  }
  final scannerConfig = ScannerConfig(
    caseStyle: scannerCaseStyle,
    allowArgumentEscapeSequence:
        config.scanner?.allowArgumentEscapeSequence ?? false,
    distanceOptions: config.scanner?.distanceOptions ?? defaultDistanceOptions,
  );
  final documentationConfig = DocumentationConfig(
    alwaysShowHelpAllFlag: config.documentation?.alwaysShowHelpAllFlag ?? false,
    useAliasInUsageLine: config.documentation?.useAliasInUsageLine ?? false,
    onlyRequiredInUsageLine:
        config.documentation?.onlyRequiredInUsageLine ?? false,
    caseStyle: displayCaseStyle,
    disableAnsiColor: config.documentation?.disableAnsiColor ?? false,
  );
  final completionConfig = CompletionConfig(
    includeAliases:
        config.completion?.includeAliases ??
        documentationConfig.useAliasInUsageLine,
    includeHiddenRoutes: config.completion?.includeHiddenRoutes ?? false,
    includeHiddenFlags: config.completion?.includeHiddenFlags ?? false,
  );
  final localizationConfig = LocalizationConfig(
    defaultLocale: config.localization?.defaultLocale ?? 'en',
    loadText: config.localization?.text != null
        ? null
        : (config.localization?.loadText ?? _defaultTextLoader),
    text: config.localization?.text,
  );
  return ResolvedApplicationConfiguration(
    name: config.name,
    scanner: scannerConfig,
    completion: completionConfig,
    documentation: documentationConfig,
    localization: localizationConfig,
    determineExitCode: config.determineExitCode,
    versionInfo: config.versionInfo,
  );
}

/// Mirror of stricli `defaultTextLoader`.
ApplicationText? _defaultTextLoader(String locale) {
  if (locale.startsWith('en')) {
    return textEn;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Application (src/application/builder.ts)
// ---------------------------------------------------------------------------

/// Mirror of a built stricli application.
final class Application {
  Application._({
    required this.root,
    required this.config,
    required this.defaultText,
    required this.integrations,
  });

  /// The root value.
  final RoutingTarget root;

  /// The resolved documentation configuration.
  final ResolvedApplicationConfiguration config;

  /// The default text value.
  final ApplicationText defaultText;

  /// Ordered integrations.
  final List<InternalIntegration> integrations;
}

List<InternalIntegration> _defaultIntegrations(
  ResolvedApplicationConfiguration config,
  ApplicationText text,
) {
  final help = InternalIntegration(
    name: 'help',
    flag: InternalApplicationFlag(
      documentation: AdditionalFlagDocumentation(
        name: 'help',
        brief: text.briefs.help,
        aliases: const ['h'],
        global: true,
        complete: true,
      ),
      defaultForRouteMap: true,
      run: (context, app, args) {
        context.process.stdout.write(
          args.result.target.formatHelp(
            HelpFormattingArguments(
              prefix: args.result.prefix,
              config: config.documentation,
              text: args.text,
              includeLegacyHelpFlag: false,
              includeArgumentEscapeSequenceFlag:
                  config.scanner.allowArgumentEscapeSequence,
              includeHidden: false,
              aliases: args.result.aliases.byStyle(
                config.documentation.caseStyle,
              ),
              additionalFlags: args.additionalFlags,
              ansiColor: args.ansiColorByStream.stdout,
            ),
          ),
        );
      },
    ),
  );
  final helpAll = InternalIntegration(
    name: 'helpAll',
    flag: InternalApplicationFlag(
      documentation: AdditionalFlagDocumentation(
        name: 'helpAll',
        brief: text.briefs.helpAll,
        aliases: const ['H'],
        hidden: !config.documentation.alwaysShowHelpAllFlag,
        global: true,
        complete: true,
      ),
      run: (context, app, args) {
        context.process.stdout.write(
          args.result.target.formatHelp(
            HelpFormattingArguments(
              prefix: args.result.prefix,
              config: config.documentation,
              text: args.text,
              includeLegacyHelpFlag: false,
              includeArgumentEscapeSequenceFlag:
                  config.scanner.allowArgumentEscapeSequence,
              includeHidden: true,
              aliases: args.result.aliases.byStyle(
                config.documentation.caseStyle,
              ),
              additionalFlags: args.additionalFlags,
              ansiColor: args.ansiColorByStream.stdout,
            ),
          ),
        );
      },
    ),
  );
  final integrations = <InternalIntegration>[help, helpAll];
  final versionInfo = config.versionInfo;
  if (versionInfo != null) {
    integrations.add(
      InternalIntegration(
        name: 'version',
        hooks: versionInfo.getLatestVersion == null
            ? null
            : InternalLifecycleHooks(
                appStart: (context, arguments) async {
                  if (_checkEnvironmentVariable(
                    context.process.readEnv,
                    'STRICLI_SKIP_VERSION_CHECK',
                  )) {
                    return;
                  }
                  final currentVersion = await versionInfo.resolveCurrent(
                    context,
                  );
                  final latestVersion = await versionInfo.getLatestVersion!(
                    context,
                    currentVersion,
                  );
                  if (latestVersion != null &&
                      latestVersion != currentVersion) {
                    final message = arguments.text.currentVersionIsNotLatest(
                      CurrentVersionNotLatestArguments(
                        currentVersion: currentVersion,
                        latestVersion: latestVersion,
                        upgradeCommand: versionInfo.upgradeCommand,
                      ),
                    );
                    _writeWarning(
                      context.process.stderr,
                      message,
                      arguments.ansiColorByStream.stderr,
                    );
                  }
                },
              ),
        flag: InternalApplicationFlag(
          documentation: AdditionalFlagDocumentation(
            name: 'version',
            brief: text.briefs.version,
            aliases: const ['v'],
            complete: true,
          ),
          run: (context, app, args) async {
            context.process.stdout.write(
              '${await versionInfo.resolveCurrent(context)}\n',
            );
          },
        ),
      ),
    );
  }
  return integrations;
}

void _validateIntegrations(
  RoutingTarget root,
  ResolvedApplicationConfiguration config,
  List<InternalIntegration> integrations,
) {
  final names = <String>{};
  final aliases = <String, String>{};
  String? defaultForRouteMap;
  for (final integration in integrations) {
    final name = integration.name;
    if (!names.add(name)) {
      throw RouterInternalError('Duplicate integration name "$name"');
    }
    if (config.scanner.caseStyle == ScannerCaseStyle.allowKebabForCamel) {
      final camelName = convertKebabCaseToCamelCase(name);
      final collision = integrations.any(
        (other) => other.name != name && other.name == camelName,
      );
      if (collision) {
        throw RouterInternalError(
          'Multiple integrations use the same flag name: "$name" and "$camelName"',
        );
      }
    }
    final flag = integration.flag;
    if (flag != null) {
      if (flag.documentation.name != name) {
        throw RouterInternalError(
          'Integration "$name" must use "$name" as its flag name',
        );
      }
      if (flag.defaultForRouteMap) {
        if (defaultForRouteMap != null) {
          throw RouterInternalError(
            'Multiple integrations provide a default flag for route maps: '
            '"$defaultForRouteMap" and "$name"',
          );
        }
        defaultForRouteMap = name;
      }
      for (final alias in flag.documentation.aliases) {
        if (alias.length != 1) {
          throw RouterInternalError(
            'Integration "$name" uses invalid alias "-$alias"',
          );
        }
        final existing = aliases[alias];
        if (existing != null) {
          throw RouterInternalError(
            'Multiple integrations use alias "-$alias": "$existing" and "$name"',
          );
        }
        aliases[alias] = name;
      }
    }
  }

  void checkTarget(RoutingTarget target, bool isRoot, List<String> prefix) {
    if (target is Command) {
      for (final integration in integrations) {
        final documentation = integration.flag?.documentation;
        if (documentation == null || (!isRoot && !documentation.global)) {
          continue;
        }
        final namesToCheck = [documentation.name, ...documentation.aliases];
        for (final name in namesToCheck) {
          final camelName = convertKebabCaseToCamelCase(name);
          if (target.usesFlag(name) ||
              (config.scanner.caseStyle ==
                      ScannerCaseStyle.allowKebabForCamel &&
                  target.usesFlag(camelName))) {
            throw RouterInternalError(
              'Integration "${integration.name}" would override '
              '"${[...prefix, name.length == 1 ? '-$name' : '--$name'].join(' ')}"',
            );
          }
        }
      }
      return;
    }
    for (final entry in (target as RouteMap).getAllEntries()) {
      checkTarget(entry.target, false, [...prefix, entry.name.original]);
    }
  }

  checkTarget(root, true, const []);
  for (final integration in integrations) {
    try {
      integration.validate?.call(root, config);
    } catch (error) {
      throw RouterInternalError(
        'Integration "${integration.name}" failed validation: $error',
      );
    }
  }
}

/// Mirror of stricli `buildApplication` (dist index.js:1505).
Application buildApplication(
  RoutingTarget root,
  ApplicationConfiguration appConfig, {
  List<InternalIntegration>? integrations,
}) {
  final config = _withDefaults(appConfig);
  ApplicationText defaultText;
  final text = config.localization.text;
  if (text != null) {
    defaultText = text;
  } else {
    final loaded = config.localization.loadText!(
      config.localization.defaultLocale,
    );
    if (loaded == null) {
      throw RouterInternalError(
        'No text available for the default locale "${config.localization.defaultLocale}"',
      );
    }
    defaultText = loaded;
  }
  final resolvedIntegrations =
      integrations ?? _defaultIntegrations(config, defaultText);
  _validateIntegrations(root, config, resolvedIntegrations);
  return Application._(
    root: root,
    config: config,
    defaultText: defaultText,
    integrations: List.unmodifiable(resolvedIntegrations),
  );
}

// ---------------------------------------------------------------------------
// Environment / ANSI helpers (src/context.ts, src/text.ts)
// ---------------------------------------------------------------------------

/// Mirror of `checkEnvironmentVariable` (loose-boolean environment check).
bool _checkEnvironmentVariable(EnvLookup readEnv, String varName) {
  final value = readEnv(varName);
  return value != null && looseBooleanParser(value);
}

/// Mirror of `shouldUseAnsiColor`; `stream.isTTY` approximates Node's
/// `stream.getColorDepth() >= 4`.
bool _shouldUseAnsiColor(
  RunProcess process,
  WriteStream stream,
  DocumentationConfig config,
) {
  return !config.disableAnsiColor &&
      !_checkEnvironmentVariable(process.readEnv, 'STRICLI_NO_COLOR') &&
      stream.isTTY;
}

void _writeError(WriteStream stream, String message, bool ansiColor) {
  stream.write(
    ansiColor ? '\x1B[1m\x1B[31m$message\x1B[39m\x1B[22m\n' : '$message\n',
  );
}

void _writeWarning(WriteStream stream, String message, bool ansiColor) {
  stream.write(
    ansiColor ? '\x1B[1m\x1B[33m$message\x1B[39m\x1B[22m\n' : '$message\n',
  );
}

// ---------------------------------------------------------------------------
// Route scanning (src/routing/scanner.ts)
// ---------------------------------------------------------------------------

final class _RouteScanError {
  const _RouteScanError({required this.input, required this.routeMap});

  final String input;
  final RouteMap routeMap;
}

/// Result of scanning inputs to select an application target.
final class RouteScanResult {
  /// Creates a route scan result.
  const RouteScanResult({
    required this.target,
    required this.unprocessedInputs,
    required this.prefix,
    required this.rootLevel,
    required this.aliases,
    this.activeFlag,
  });

  /// Selected command or route map.
  final RoutingTarget target;

  /// Inputs not consumed by route scanning.
  final List<String> unprocessedInputs;

  /// Consumed route prefix.
  final List<String> prefix;

  /// Whether [target] is the root.
  final bool rootLevel;

  /// Other aliases for the selected route.
  final RouteNameAliases aliases;

  /// First active integration application flag.
  final InternalApplicationFlag? activeFlag;
}

final class _RouteScanner {
  _RouteScanner(
    RoutingTarget root,
    this.config,
    List<String> startingPrefix,
    this.additionalFlags,
  ) : prefix = [...startingPrefix],
      _root = root,
      _current = root;

  final ScannerConfig config;
  final RoutingTarget _root;
  final List<InternalApplicationFlag> additionalFlags;
  final List<String> prefix;
  final List<String> unprocessedInputs = [];
  (RouteMap, String)? _parent;
  RoutingTarget _current;
  RoutingTarget? _target;
  bool _rootLevel = true;
  InternalApplicationFlag? _activeFlag;
  bool _treatInputsAsArguments = false;

  _RouteScanError? next(String input) {
    if (!_treatInputsAsArguments &&
        config.allowArgumentEscapeSequence &&
        input == '--') {
      _treatInputsAsArguments = true;
      unprocessedInputs.add(input);
      return null;
    }
    if (!_treatInputsAsArguments) {
      final relevantFlags = additionalFlags.where(
        (flag) => identical(_current, _root) || flag.documentation.global,
      );
      InternalApplicationFlag? matchedFlag;
      if (input.startsWith('--')) {
        final inputName = input.substring(2);
        for (final flag in relevantFlags) {
          final name = flag.documentation.name;
          if (inputName == name ||
              (config.caseStyle == ScannerCaseStyle.allowKebabForCamel &&
                  convertKebabCaseToCamelCase(inputName) == name)) {
            matchedFlag = flag;
            break;
          }
        }
      } else if (input.startsWith('-') && !input.startsWith('--')) {
        final aliases = input.substring(1).split('');
        for (final alias in aliases) {
          for (final flag in relevantFlags) {
            if (flag.documentation.aliases.contains(alias)) {
              matchedFlag = flag;
              break;
            }
          }
          if (matchedFlag != null) {
            break;
          }
        }
      }
      if (matchedFlag != null) {
        _activeFlag = matchedFlag;
        _target ??= _current;
        return null;
      }
    }
    if (_target != null) {
      unprocessedInputs.add(input);
      return null;
    }
    final current = _current;
    if (current is Command) {
      _target = current;
      unprocessedInputs.add(input);
      return null;
    }
    final routeMap = current as RouteMap;
    final camelCaseRouteName = convertKebabCaseToCamelCase(input);
    var internalRouteName = input;
    var nextTarget = routeMap.getRoutingTargetForInput(internalRouteName);
    if (config.caseStyle == ScannerCaseStyle.allowKebabForCamel &&
        nextTarget == null) {
      nextTarget = routeMap.getRoutingTargetForInput(camelCaseRouteName);
      if (nextTarget != null) {
        internalRouteName = camelCaseRouteName;
      }
    }
    if (nextTarget == null) {
      final defaultCommand = routeMap.getDefaultCommand();
      if (defaultCommand != null) {
        _rootLevel = false;
        _parent = (routeMap, '');
        unprocessedInputs.add(input);
        _current = defaultCommand;
        return null;
      }
      return _RouteScanError(input: input, routeMap: routeMap);
    }
    _rootLevel = false;
    _parent = (routeMap, input);
    _current = nextTarget;
    prefix.add(input);
    return null;
  }

  RouteScanResult finish() {
    var target = _target ?? _current;
    if (target is RouteMap && _activeFlag == null) {
      final defaultCommand = target.getDefaultCommand();
      if (defaultCommand != null) {
        _parent = (target, '');
        target = defaultCommand;
        _rootLevel = false;
      }
    }
    final parent = _parent;
    final aliases = parent != null
        ? parent.$1.getOtherAliasesForInput(parent.$2, config.caseStyle)
        : const RouteNameAliases.empty();
    return RouteScanResult(
      target: target,
      unprocessedInputs: unprocessedInputs,
      prefix: prefix,
      rootLevel: _rootLevel,
      aliases: aliases,
      activeFlag: _activeFlag,
    );
  }
}

/// Mirror of `listAllRouteNamesAndAliasesForScan` (dist index.js:1052).
List<String> _listAllRouteNamesAndAliasesForScan(
  RouteMap routeMap,
  ScannerCaseStyle scannerCaseStyle,
  CompletionConfig config,
) {
  final displayCaseStyle =
      scannerCaseStyle == ScannerCaseStyle.allowKebabForCamel
      ? DisplayCaseStyle.convertCamelToKebab
      : DisplayCaseStyle.original;
  var entries = routeMap.getAllEntries();
  if (!config.includeHiddenRoutes) {
    entries = entries.where((entry) => !entry.hidden).toList();
  }
  return entries.expand((entry) {
    final routeName = entry.name.byStyle(displayCaseStyle);
    if (config.includeAliases) {
      return [routeName, ...entry.aliases];
    }
    return [routeName];
  }).toList();
}

// ---------------------------------------------------------------------------
// Command running (src/routing/command/run.ts)
// ---------------------------------------------------------------------------

Future<int> _runCommand(
  Command command, {
  required RunContext context,
  required List<String> inputs,
  required ScannerConfig scannerConfig,
  required DocumentationConfig documentationConfig,
  required ApplicationText errorFormatting,
  int Function(Object? error)? determineExitCode,
}) async {
  Map<String, Object?> parsedFlags;
  List<Object?> parsedPositional;
  try {
    final scanner = _ArgumentScanner(command.parameters, scannerConfig);
    for (final input in inputs) {
      scanner.next(input);
    }
    final result = await scanner.parseArguments(context);
    switch (result) {
      case _ScanSuccess(:final flags, :final positional):
        parsedFlags = flags;
        parsedPositional = positional;
      case _ScanFailure(:final errors):
        final ansiColor = _shouldUseAnsiColor(
          context.process,
          context.process.stderr,
          documentationConfig,
        );
        for (final error in errors) {
          final errorMessage = errorFormatting.exceptionWhileParsingArguments(
            error,
            ansiColor,
          );
          _writeError(context.process.stderr, errorMessage, ansiColor);
        }
        return ExitCode.invalidArgument;
    }
  } catch (exc) {
    final ansiColor = _shouldUseAnsiColor(
      context.process,
      context.process.stderr,
      documentationConfig,
    );
    final errorMessage = errorFormatting.exceptionWhileParsingArguments(
      exc,
      ansiColor,
    );
    _writeError(context.process.stderr, errorMessage, ansiColor);
    return ExitCode.invalidArgument;
  }
  CommandFunction commandFunction;
  try {
    commandFunction = await command.loader();
  } catch (exc) {
    final ansiColor = _shouldUseAnsiColor(
      context.process,
      context.process.stderr,
      documentationConfig,
    );
    final errorMessage = errorFormatting.exceptionWhileLoadingCommandFunction(
      exc,
      ansiColor,
    );
    _writeError(context.process.stderr, errorMessage, ansiColor);
    return ExitCode.commandLoadError;
  }
  try {
    final result = await commandFunction(
      context,
      parsedFlags,
      parsedPositional,
    );
    if (result is Error || result is Exception) {
      final ansiColor = _shouldUseAnsiColor(
        context.process,
        context.process.stderr,
        documentationConfig,
      );
      final errorMessage = errorFormatting.commandErrorResult(
        result as Object,
        ansiColor,
      );
      _writeError(context.process.stderr, errorMessage, ansiColor);
      if (determineExitCode != null) {
        return determineExitCode(result);
      }
      return ExitCode.commandRunError;
    }
  } catch (exc) {
    final ansiColor = _shouldUseAnsiColor(
      context.process,
      context.process.stderr,
      documentationConfig,
    );
    final errorMessage = errorFormatting.exceptionWhileRunningCommand(
      exc,
      ansiColor,
    );
    _writeError(context.process.stderr, errorMessage, ansiColor);
    if (determineExitCode != null) {
      return determineExitCode(exc);
    }
    return ExitCode.commandRunError;
  }
  return ExitCode.success;
}

// ---------------------------------------------------------------------------
// Application running (src/application/run.ts, src/index.ts)
// ---------------------------------------------------------------------------

AnsiColorByStream _resolveAnsiColorByStream(
  RunContext context,
  DocumentationConfig config,
) {
  return AnsiColorByStream(
    stdout: _shouldUseAnsiColor(
      context.process,
      context.process.stdout,
      config,
    ),
    stderr: _shouldUseAnsiColor(
      context.process,
      context.process.stderr,
      config,
    ),
  );
}

Future<int?> _runIntegrationHooks(
  Application app,
  String hookName,
  RunContext context,
  ApplicationHookArguments arguments,
) async {
  for (final integration in app.integrations) {
    final hooks = integration.hooks;
    if (hooks == null) {
      continue;
    }
    final hook = switch (hookName) {
      'app:start' =>
        hooks.appStart == null
            ? null
            : () => hooks.appStart!(context, arguments),
      'app:end' =>
        hooks.appEnd == null ? null : () => hooks.appEnd!(context, arguments),
      'command:start' =>
        hooks.commandStart == null
            ? null
            : () => hooks.commandStart!(
                context,
                arguments as InternalCommandHookArguments,
              ),
      'command:end' =>
        hooks.commandEnd == null
            ? null
            : () => hooks.commandEnd!(
                context,
                arguments as InternalCommandHookArguments,
              ),
      _ => null,
    };
    if (hook == null) {
      continue;
    }
    try {
      await hook();
    } catch (error) {
      final message = arguments.text.exceptionWhileRunningIntegrationHook(
        IntegrationHookErrorArguments(
          exception: error,
          hook: hookName,
          integration: integration.name,
          ansiColor: arguments.ansiColorByStream.stderr,
        ),
      );
      _writeError(
        context.process.stderr,
        message,
        arguments.ansiColorByStream.stderr,
      );
      return ExitCode.integrationError;
    }
  }
  return null;
}

List<InternalApplicationFlag> _applicationFlags(Application app) {
  return [for (final integration in app.integrations) ?integration.flag];
}

Future<int> _scanInputsAndRunTarget(
  Application app,
  List<String> rawInputs,
  RunContext context,
  ApplicationText text,
  AnsiColorByStream ansiColorByStream,
) async {
  final config = app.config;
  final applicationFlags = _applicationFlags(app);
  final inputs = [...rawInputs];
  final scanner = _RouteScanner(app.root, config.scanner, [
    config.name,
  ], applicationFlags);
  _RouteScanError? error;
  while (inputs.isNotEmpty && error == null) {
    error = scanner.next(inputs.removeAt(0));
  }
  if (error != null) {
    final routeNames = _listAllRouteNamesAndAliasesForScan(
      error.routeMap,
      config.scanner.caseStyle,
      config.completion,
    );
    final corrections = filterClosestAlternatives(
      error.input,
      routeNames,
      config.scanner.distanceOptions,
    ).map((str) => '`$str`').toList();
    final errorMessage = text.noCommandRegisteredForInput(
      NoCommandRegisteredArguments(
        input: error.input,
        corrections: corrections,
        ansiColor: ansiColorByStream.stderr,
      ),
    );
    _writeError(context.process.stderr, errorMessage, ansiColorByStream.stderr);
    return ExitCode.unknownCommand;
  }

  final result = scanner.finish();
  var activeFlag = result.activeFlag;
  if (activeFlag == null && result.target is RouteMap) {
    for (final flag in applicationFlags) {
      if (flag.defaultForRouteMap) {
        activeFlag = flag;
        break;
      }
    }
  }
  if (activeFlag != null || result.target is RouteMap) {
    if (activeFlag != null) {
      final relevantFlags = result.rootLevel
          ? applicationFlags
          : applicationFlags
                .where((flag) => flag.documentation.global)
                .toList();
      try {
        await activeFlag.run(
          context,
          app,
          IntegrationFlagArguments(
            text: text,
            ansiColorByStream: ansiColorByStream,
            result: result,
            additionalFlags: List.unmodifiable(
              relevantFlags.map((flag) => flag.documentation),
            ),
          ),
        );
      } catch (error) {
        final integrationName = activeFlag.documentation.name;
        final message = text.exceptionWhileRunningIntegrationFlag(
          IntegrationFlagErrorArguments(
            exception: error,
            integration: integrationName,
            ansiColor: ansiColorByStream.stderr,
          ),
        );
        _writeError(context.process.stderr, message, ansiColorByStream.stderr);
        return ExitCode.integrationError;
      }
    }
    return ExitCode.success;
  }

  final contextLoader = context.forCommand;
  if (contextLoader != null) {
    try {
      context.commandContext = await contextLoader(result.prefix);
    } catch (error) {
      final errorMessage = text.exceptionWhileLoadingCommandContext(
        error,
        ansiColorByStream.stderr,
      );
      _writeError(
        context.process.stderr,
        errorMessage,
        ansiColorByStream.stderr,
      );
      return ExitCode.contextLoadError;
    }
  }
  final commandArguments = InternalCommandHookArguments(
    text: text,
    ansiColorByStream: ansiColorByStream,
    result: result,
  );
  final hookStartCode = await _runIntegrationHooks(
    app,
    'command:start',
    context,
    commandArguments,
  );
  if (hookStartCode != null) {
    return hookStartCode;
  }
  final commandExitCode = await _runCommand(
    result.target as Command,
    context: context,
    inputs: result.unprocessedInputs,
    scannerConfig: config.scanner,
    documentationConfig: config.documentation,
    errorFormatting: text,
    determineExitCode: config.determineExitCode,
  );
  final hookEndCode = await _runIntegrationHooks(
    app,
    'command:end',
    context,
    InternalCommandHookArguments(
      text: text,
      ansiColorByStream: ansiColorByStream,
      result: result,
      exitCode: commandExitCode,
    ),
  );
  return hookEndCode ?? commandExitCode;
}

/// Mirror of stricli `runApplication`; returns the process exit code.
Future<int> runApplication(
  Application app,
  List<String> rawInputs,
  RunContext context,
) async {
  final config = app.config;
  var text = app.defaultText;
  final locale = context.locale;
  final loadText = config.localization.loadText;
  if (locale != null && loadText != null) {
    final localeText = loadText(locale);
    if (localeText != null) {
      text = localeText;
    } else {
      final ansiColor = _shouldUseAnsiColor(
        context.process,
        context.process.stderr,
        config.documentation,
      );
      final warningMessage = text.noTextAvailableForLocale(
        NoTextAvailableArguments(
          requestedLocale: locale,
          defaultLocale: config.localization.defaultLocale,
          ansiColor: ansiColor,
        ),
      );
      _writeWarning(context.process.stderr, warningMessage, ansiColor);
    }
  }
  final ansiColorByStream = _resolveAnsiColorByStream(
    context,
    config.documentation,
  );
  final appStartCode = await _runIntegrationHooks(
    app,
    'app:start',
    context,
    ApplicationHookArguments(text: text, ansiColorByStream: ansiColorByStream),
  );
  if (appStartCode != null) {
    return appStartCode;
  }
  final exitCode = await _scanInputsAndRunTarget(
    app,
    rawInputs,
    context,
    text,
    ansiColorByStream,
  );
  final appEndCode = await _runIntegrationHooks(
    app,
    'app:end',
    context,
    ApplicationHookArguments(
      text: text,
      ansiColorByStream: ansiColorByStream,
      exitCode: exitCode,
    ),
  );
  return appEndCode ?? exitCode;
}

/// Mirror of stricli `run`: runs the application and assigns the exit code to
/// the context process unless a command already set one.
Future<void> run(
  Application app,
  List<String> inputs,
  RunContext context,
) async {
  final exitCode = await runApplication(app, inputs, context);
  context.process.exitCode ??= exitCode;
}

// ---------------------------------------------------------------------------
// Completion proposals (src/application/propose-completions.ts)
// ---------------------------------------------------------------------------

/// A single completion proposal; `kind` mirrors the TS literal union
/// (`routing-target:command`, `routing-target:route-map`, `argument:flag`,
/// `argument:value`).
final class InputCompletion {
  /// Creates an [InputCompletion].
  const InputCompletion({
    required this.kind,
    required this.completion,
    required this.brief,
  });

  /// The kind value.
  final String kind;

  /// The proposed completion value.
  final String completion;

  /// The short description shown in help output.
  final String brief;
}

/// Mirror of `proposeCompletionsForRouteMap` (dist index.js:1595).
Future<List<InputCompletion>> _proposeCompletionsForRouteMap(
  RouteMap routeMap, {
  required String partial,
  required ScannerConfig scannerConfig,
  required CompletionConfig completionConfig,
}) async {
  var entries = routeMap.getAllEntries();
  if (!completionConfig.includeHiddenRoutes) {
    entries = entries.where((entry) => !entry.hidden).toList();
  }
  final displayCaseStyle =
      scannerConfig.caseStyle == ScannerCaseStyle.allowKebabForCamel
      ? DisplayCaseStyle.convertCamelToKebab
      : DisplayCaseStyle.original;
  return entries
      .expand((entry) {
        final kind = entry.target is Command
            ? 'routing-target:command'
            : 'routing-target:route-map';
        final brief = entry.target.brief;
        final targetCompletion = InputCompletion(
          kind: kind,
          completion: entry.name.byStyle(displayCaseStyle),
          brief: brief,
        );
        if (completionConfig.includeAliases) {
          return [
            targetCompletion,
            ...entry.aliases.map(
              (alias) =>
                  InputCompletion(kind: kind, completion: alias, brief: brief),
            ),
          ];
        }
        return [targetCompletion];
      })
      .where((completion) => completion.completion.startsWith(partial))
      .toList();
}

/// Mirror of `proposeCompletionsForCommand` (dist index.js:1582).
Future<List<InputCompletion>> _proposeCompletionsForCommand(
  Command command, {
  required RunContext context,
  required List<String> inputs,
  required String partial,
  required ScannerConfig scannerConfig,
  required CompletionConfig completionConfig,
  required ApplicationText text,
  required bool includeVersionFlag,
}) async {
  try {
    final scanner = _ArgumentScanner(command.parameters, scannerConfig);
    for (final input in inputs) {
      scanner.next(input);
    }
    return await scanner.proposeCompletions(
      partial: partial,
      completionConfig: completionConfig,
      text: text,
      context: context,
      includeVersionFlag: includeVersionFlag,
    );
  } catch (_) {
    return [];
  }
}

/// Mirror of stricli `proposeCompletions` (`proposeCompletionsForApplication`).
Future<List<InputCompletion>> proposeCompletions(
  Application app,
  List<String> rawInputs,
  RunContext context,
) async {
  if (rawInputs.isEmpty) {
    return [];
  }
  final config = app.config;
  final applicationFlags = _applicationFlags(app);
  final scanner = _RouteScanner(app.root, config.scanner, [], applicationFlags);
  final leadingInputs = rawInputs.sublist(0, rawInputs.length - 1);
  _RouteScanError? error;
  while (leadingInputs.isNotEmpty && error == null) {
    final input = leadingInputs.removeAt(0);
    error = scanner.next(input);
  }
  if (error != null) {
    return [];
  }
  final result = scanner.finish();
  if (result.activeFlag != null) {
    return [];
  }
  final contextLoader = context.forCommand;
  if (contextLoader != null) {
    try {
      context.commandContext = await contextLoader(result.prefix);
    } catch (_) {
      return [];
    }
  }
  final partial = rawInputs[rawInputs.length - 1];
  final relevantFlags = result.rootLevel
      ? applicationFlags
      : applicationFlags.where((flag) => flag.documentation.global).toList();
  final additionalCompletions = <InputCompletion>[];
  if (partial.startsWith('-')) {
    for (final flag in relevantFlags) {
      final documentation = flag.documentation;
      if (!documentation.complete ||
          (documentation.hidden && !config.completion.includeHiddenRoutes)) {
        continue;
      }
      final names = <String>[
        '--${documentation.name}',
        if (config.scanner.caseStyle == ScannerCaseStyle.allowKebabForCamel &&
            convertCamelCaseToKebabCase(documentation.name) !=
                documentation.name)
          '--${convertCamelCaseToKebabCase(documentation.name)}',
        if (config.completion.includeAliases)
          ...documentation.aliases.map((alias) => '-$alias'),
      ];
      additionalCompletions.addAll(
        names
            .where((name) => name.startsWith(partial))
            .map(
              (name) => InputCompletion(
                kind: 'argument:flag',
                completion: name,
                brief: documentation.brief,
              ),
            ),
      );
    }
  }
  final target = result.target;
  if (target is RouteMap) {
    final targetCompletions = await _proposeCompletionsForRouteMap(
      target,
      partial: partial,
      scannerConfig: config.scanner,
      completionConfig: config.completion,
    );
    return [...targetCompletions, ...additionalCompletions];
  }
  final targetCompletions = await _proposeCompletionsForCommand(
    target as Command,
    context: context,
    inputs: result.unprocessedInputs,
    partial: partial,
    scannerConfig: config.scanner,
    completionConfig: config.completion,
    text: app.defaultText,
    includeVersionFlag: false,
  );
  return [...targetCompletions, ...additionalCompletions];
}
