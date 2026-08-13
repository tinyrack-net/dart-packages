import 'dart:async';

import 'package:cliweave/src/router.dart' as raw;

export 'package:cliweave/src/router.dart'
    show
        AliasNotFoundError,
        ApplicationText,
        ArgumentParseError,
        ArgumentScannerError,
        CompletionConfiguration,
        CurrentVersionNotLatestArguments,
        DisplayCaseStyle,
        DistanceOptions,
        DistanceWeights,
        DocumentationConfiguration,
        EnumValidationError,
        ExitCode,
        FlagNotFoundError,
        InputCompletion,
        InvalidNegatedFlagSyntaxError,
        LocalizationConfiguration,
        NoCommandRegisteredArguments,
        NoTextAvailableArguments,
        RouterInternalError,
        RunProcess,
        ScannerCaseStyle,
        ScannerConfiguration,
        TextBriefs,
        TextHeaders,
        TextKeywords,
        UnexpectedFlagError,
        UnexpectedPositionalError,
        UnsatisfiedFlagError,
        UnsatisfiedPositionalError,
        defaultDistanceOptions,
        filterClosestAlternatives,
        formatMessageForArgumentScannerError,
        joinWithGrammar,
        textEn;

/// Documentation attached to a command.
typedef CommandDocs = raw.CommandDocs;

/// Documentation attached to a route map.
typedef RouteMapDocs = raw.RouteMapDocs;

/// Resolved application configuration.
typedef ResolvedApplicationConfiguration = raw.ResolvedApplicationConfiguration;

/// Process abstraction used by command contexts.
typedef RunProcess = raw.RunProcess;

/// A command-specific context.
abstract interface class CommandContext {
  /// Process streams and environment exposed to commands.
  RunProcess get process;
}

/// Minimal context suitable for applications that do not need custom state.
final class ApplicationContext implements CommandContext {
  /// Creates an application context.
  const ApplicationContext({required this.process, this.locale});

  @override
  final RunProcess process;

  /// Requested locale.
  final String? locale;
}

/// Route information supplied while constructing a command context.
final class CommandInfo {
  /// Creates command information.
  const CommandInfo(this.prefix);

  /// Inputs consumed while navigating to the command.
  final List<String> prefix;
}

/// Builds context for one command invocation.
typedef CommandContextBuilder<C extends CommandContext> = FutureOr<C> Function(
  CommandInfo info,
);

/// Runtime context source used by [run], [runApplication], and completion.
final class RunContext<C extends CommandContext> {
  RunContext._(this._raw);

  /// Uses one prebuilt context for every command.
  factory RunContext.direct(C context, {String? locale}) {
    return RunContext._(
      raw.RunContext(
        process: context.process,
        locale: locale,
        commandContext: context,
      ),
    );
  }

  /// Creates context independently for each selected command.
  factory RunContext.forCommands({
    required ApplicationContext application,
    required CommandContextBuilder<C> load,
  }) {
    return RunContext._(
      raw.RunContext(
        process: application.process,
        locale: application.locale,
        forCommand: (prefix) => load(CommandInfo(List.unmodifiable(prefix))),
      ),
    );
  }

  final raw.RunContext _raw;
}

/// Marker returned by a command with no flags.
final class NoFlags {
  /// The only no-flags value.
  const NoFlags();
}

/// Marker returned by a command with no positional arguments.
final class NoArgs {
  /// The only no-arguments value.
  const NoArgs();
}

/// Parses one CLI input with access to the command context.
typedef InputParser<T, C extends CommandContext> = FutureOr<T> Function(
  C context,
  String input,
);

/// Proposes values with access to the command context.
typedef ValueCompletion<C extends CommandContext> =
    FutureOr<List<String>> Function(C context, String partial);

C _commandContext<C extends CommandContext>(raw.RunContext context) {
  final value = context.commandContext;
  if (value is! C) {
    throw StateError('No command context of type $C is available');
  }
  return value;
}

/// Typed flag declaration.
final class FlagBinding<T, C extends CommandContext> {
  FlagBinding._(this.name, this._raw, this._decode);

  /// Internal flag name.
  final String name;
  final raw.Flag _raw;
  final T Function(Object? value) _decode;
}

/// Factories for boolean flags.
abstract final class BooleanFlag {
  /// A boolean that resolves to false when omitted.
  static FlagBinding<bool, C> required<C extends CommandContext>({
    required String name,
    required String brief,
    bool hidden = false,
    bool withNegated = true,
  }) {
    return FlagBinding._(
      name,
      raw.BooleanFlag(brief: brief, hidden: hidden, withNegated: withNegated),
      (value) => value! as bool,
    );
  }

  /// A nullable boolean.
  static FlagBinding<bool?, C> optional<C extends CommandContext>({
    required String name,
    required String brief,
    bool hidden = false,
    bool withNegated = true,
  }) {
    return FlagBinding._(
      name,
      raw.BooleanFlag(
        brief: brief,
        optional: true,
        hidden: hidden,
        withNegated: withNegated,
      ),
      (value) => value as bool?,
    );
  }

  /// A boolean with an omission default.
  static FlagBinding<bool, C> defaulted<C extends CommandContext>({
    required String name,
    required String brief,
    required bool defaultValue,
    bool hidden = false,
    bool withNegated = true,
  }) {
    return FlagBinding._(
      name,
      raw.BooleanFlag(
        brief: brief,
        defaultValue: defaultValue,
        hidden: hidden,
        withNegated: withNegated,
      ),
      (value) => value! as bool,
    );
  }
}

/// Factories for counter flags.
abstract final class CounterFlag {
  /// A counter that resolves to zero when omitted.
  static FlagBinding<int, C> required<C extends CommandContext>({
    required String name,
    required String brief,
    bool hidden = false,
  }) {
    return FlagBinding._(
      name,
      raw.CounterFlag(brief: brief, hidden: hidden),
      (value) => value! as int,
    );
  }

  /// A nullable counter.
  static FlagBinding<int?, C> optional<C extends CommandContext>({
    required String name,
    required String brief,
    bool hidden = false,
  }) {
    return FlagBinding._(
      name,
      raw.CounterFlag(brief: brief, optional: true, hidden: hidden),
      (value) => value as int?,
    );
  }
}

/// Factories for a finite set of CLI choices.
abstract final class EnumFlag {
  /// A required choice.
  static FlagBinding<T, C> required<T, C extends CommandContext>({
    required String name,
    required String brief,
    required Map<String, T> values,
    String? placeholder,
  }) {
    return FlagBinding._(
      name,
      raw.EnumFlag(
        brief: brief,
        values: List.unmodifiable(values.keys),
        placeholder: placeholder,
      ),
      (value) => values[value as String] as T,
    );
  }

  /// An optional choice.
  static FlagBinding<T?, C> optional<T, C extends CommandContext>({
    required String name,
    required String brief,
    required Map<String, T> values,
    String? placeholder,
    bool hidden = false,
  }) {
    return FlagBinding._(
      name,
      raw.EnumFlag(
        brief: brief,
        values: List.unmodifiable(values.keys),
        placeholder: placeholder,
        optional: true,
        hidden: hidden,
      ),
      (value) => value == null ? null : values[value as String] as T,
    );
  }

  /// A choice with an omission default.
  static FlagBinding<T, C> defaulted<T, C extends CommandContext>({
    required String name,
    required String brief,
    required Map<String, T> values,
    required String defaultValue,
    String? placeholder,
    bool hidden = false,
  }) {
    return FlagBinding._(
      name,
      raw.EnumFlag(
        brief: brief,
        values: List.unmodifiable(values.keys),
        placeholder: placeholder,
        defaultValue: defaultValue,
        hidden: hidden,
      ),
      (value) => values[value as String] as T,
    );
  }

  /// A variadic choice.
  static FlagBinding<List<T>, C> variadic<T, C extends CommandContext>({
    required String name,
    required String brief,
    required Map<String, T> values,
    bool optional = true,
    String? separator,
    List<String>? defaultValues,
    String? placeholder,
  }) {
    return FlagBinding._(
      name,
      raw.EnumFlag(
        brief: brief,
        values: List.unmodifiable(values.keys),
        optional: optional,
        variadic: true,
        variadicSeparator: separator,
        defaultValue: defaultValues,
        placeholder: placeholder,
      ),
      (value) => List<T>.unmodifiable(
        (value as List<String>? ?? const []).map((item) => values[item] as T),
      ),
    );
  }

  /// A required string choice.
  static FlagBinding<String, C> strings<C extends CommandContext>({
    required String name,
    required String brief,
    required List<String> values,
    String? placeholder,
  }) {
    return required<String, C>(
      name: name,
      brief: brief,
      values: {for (final value in values) value: value},
      placeholder: placeholder,
    );
  }
}

/// Factories for parser-backed flags.
abstract final class ParsedFlag {
  static raw.ParsedFlag _raw<T, C extends CommandContext>({
    required String brief,
    required InputParser<T, C> parse,
    bool? optional,
    bool hidden = false,
    bool variadic = false,
    String? separator,
    String? placeholder,
    Object? defaultValue,
    bool inferEmpty = false,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return raw.ParsedFlag(
      brief: brief,
      parse: (_) => throw StateError('Typed parser requires context'),
      contextualParse: (context, input) =>
          parse(_commandContext<C>(context), input),
      optional: optional,
      hidden: hidden,
      variadic: variadic,
      variadicSeparator: separator,
      placeholder: placeholder,
      defaultValue: defaultValue,
      inferEmpty: inferEmpty,
      contextualProposeCompletions: proposeCompletions == null
          ? null
          : (context, partial) =>
                proposeCompletions(_commandContext<C>(context), partial),
    );
  }

  /// A required parsed value.
  static FlagBinding<T, C> required<T, C extends CommandContext>({
    required String name,
    required String brief,
    required InputParser<T, C> parse,
    String? placeholder,
    bool inferEmpty = false,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return FlagBinding._(
      name,
      _raw(
        brief: brief,
        parse: parse,
        placeholder: placeholder,
        inferEmpty: inferEmpty,
        proposeCompletions: proposeCompletions,
      ),
      (value) => value as T,
    );
  }

  /// An optional parsed value.
  static FlagBinding<T?, C> optional<T, C extends CommandContext>({
    required String name,
    required String brief,
    required InputParser<T, C> parse,
    String? placeholder,
    bool hidden = false,
    bool inferEmpty = false,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return FlagBinding._(
      name,
      _raw(
        brief: brief,
        parse: parse,
        optional: true,
        hidden: hidden,
        placeholder: placeholder,
        inferEmpty: inferEmpty,
        proposeCompletions: proposeCompletions,
      ),
      (value) => value as T?,
    );
  }

  /// A parsed value with a raw omission default.
  static FlagBinding<T, C> defaulted<T, C extends CommandContext>({
    required String name,
    required String brief,
    required InputParser<T, C> parse,
    required String defaultValue,
    String? placeholder,
    bool hidden = false,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return FlagBinding._(
      name,
      _raw(
        brief: brief,
        parse: parse,
        defaultValue: defaultValue,
        hidden: hidden,
        placeholder: placeholder,
        proposeCompletions: proposeCompletions,
      ),
      (value) => value as T,
    );
  }

  /// A variadic parsed value.
  static FlagBinding<List<T>, C> variadic<T, C extends CommandContext>({
    required String name,
    required String brief,
    required InputParser<T, C> parse,
    bool optional = true,
    String? separator,
    List<String>? defaultValues,
    String? placeholder,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return FlagBinding._(
      name,
      _raw(
        brief: brief,
        parse: parse,
        optional: optional,
        variadic: true,
        separator: separator,
        defaultValue: defaultValues,
        placeholder: placeholder,
        proposeCompletions: proposeCompletions,
      ),
      (value) =>
          List<T>.unmodifiable((value as List<Object?>? ?? const []).cast<T>()),
    );
  }
}

/// A typed decoder for all flags of a command.
final class FlagSet<T, C extends CommandContext> {
  FlagSet._(this._bindings, this._decode);

  /// No flags.
  factory FlagSet.none() {
    return FlagSet._(<FlagBinding<dynamic, C>>[], (_) => const NoFlags())
        as FlagSet<T, C>;
  }

  /// Starts a set from one flag.
  factory FlagSet.one(FlagBinding<T, C> binding) {
    return FlagSet._([
      binding as FlagBinding<dynamic, C>,
    ], (values) => binding._decode(values[binding.name]));
  }

  final List<FlagBinding<dynamic, C>> _bindings;
  final T Function(Map<String, Object?> values) _decode;

  /// Appends one flag and returns a typed pair.
  FlagSet<(T, U), C> and<U>(FlagBinding<U, C> binding) {
    if (_bindings.any((item) => item.name == binding.name)) {
      throw raw.RouterInternalError(
        'Duplicate flag declaration --${binding.name}',
      );
    }
    return FlagSet._([
      ..._bindings,
      binding as FlagBinding<dynamic, C>,
    ], (values) => (_decode(values), binding._decode(values[binding.name])));
  }

  /// Maps decoded values to a closed record or user class.
  FlagSet<R, C> map<R>(R Function(T value) transform) {
    return FlagSet._(_bindings, (values) => transform(_decode(values)));
  }
}

/// Typed positional declaration.
final class PositionalBinding<T, C extends CommandContext> {
  PositionalBinding._(this._raw, this._decode);

  final raw.PositionalParameter _raw;
  final T Function(Object? value) _decode;
}

/// Factories for positional parameters.
abstract final class Positional {
  static raw.PositionalParameter _raw<T, C extends CommandContext>({
    required String brief,
    required InputParser<T, C> parse,
    String? placeholder,
    String? defaultValue,
    bool? optional,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return raw.PositionalParameter(
      brief: brief,
      parse: (_) => throw StateError('Typed parser requires context'),
      contextualParse: (context, input) =>
          parse(_commandContext<C>(context), input),
      placeholder: placeholder,
      defaultValue: defaultValue,
      optional: optional,
      contextualProposeCompletions: proposeCompletions == null
          ? null
          : (context, partial) =>
                proposeCompletions(_commandContext<C>(context), partial),
    );
  }

  /// A required positional value.
  static PositionalBinding<T, C> required<T, C extends CommandContext>({
    required String brief,
    required InputParser<T, C> parse,
    String? placeholder,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return PositionalBinding._(
      _raw(
        brief: brief,
        parse: parse,
        placeholder: placeholder,
        proposeCompletions: proposeCompletions,
      ),
      (value) => value as T,
    );
  }

  /// An optional positional value.
  static PositionalBinding<T?, C> optional<T, C extends CommandContext>({
    required String brief,
    required InputParser<T, C> parse,
    String? placeholder,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return PositionalBinding._(
      _raw(
        brief: brief,
        parse: parse,
        placeholder: placeholder,
        optional: true,
        proposeCompletions: proposeCompletions,
      ),
      (value) => value as T?,
    );
  }

  /// A positional value with a raw omission default.
  static PositionalBinding<T, C> defaulted<T, C extends CommandContext>({
    required String brief,
    required InputParser<T, C> parse,
    required String defaultValue,
    String? placeholder,
    ValueCompletion<C>? proposeCompletions,
  }) {
    return PositionalBinding._(
      _raw(
        brief: brief,
        parse: parse,
        placeholder: placeholder,
        defaultValue: defaultValue,
        proposeCompletions: proposeCompletions,
      ),
      (value) => value as T,
    );
  }
}

/// A typed decoder for positional inputs.
final class PositionalSet<T, C extends CommandContext> {
  PositionalSet._tuple(this._bindings, this._decode)
    : _array = null,
      _minimum = null,
      _maximum = null;

  PositionalSet._array(
    this._array,
    this._decode, {
    required this._minimum,
    required this._maximum,
  }) : _bindings = const [];

  /// No positional arguments.
  static PositionalSet<NoArgs, C> none<C extends CommandContext>() {
    return PositionalSet._tuple(const [], (_) => const NoArgs());
  }

  /// Starts a tuple from one positional value.
  static PositionalSet<T, C> one<T, C extends CommandContext>(
    PositionalBinding<T, C> binding,
  ) {
    return PositionalSet._tuple([
      binding,
    ], (values) => binding._decode(values[0]));
  }

  /// Creates a homogeneous positional array.
  static PositionalSet<List<T>, C> array<T, C extends CommandContext>(
    PositionalBinding<T, C> binding, {
    int? minimum,
    int? maximum,
  }) {
    return PositionalSet._array(
      binding,
      (values) =>
          List<T>.unmodifiable(values.map((value) => binding._decode(value))),
      minimum: minimum,
      maximum: maximum,
    );
  }

  final List<PositionalBinding<dynamic, C>> _bindings;
  final PositionalBinding<dynamic, C>? _array;
  final T Function(List<Object?> values) _decode;
  final int? _minimum;
  final int? _maximum;

  /// Appends one tuple element.
  PositionalSet<(T, U), C> and<U>(PositionalBinding<U, C> binding) {
    if (_array != null) {
      throw raw.RouterInternalError(
        'Cannot append a positional parameter to an array layout',
      );
    }
    final index = _bindings.length;
    return PositionalSet._tuple([
      ..._bindings,
      binding as PositionalBinding<dynamic, C>,
    ], (values) => (_decode(values), binding._decode(values[index])));
  }

  /// Maps decoded values to a closed record or user class.
  PositionalSet<R, C> map<R>(R Function(T value) transform) {
    if (_array != null) {
      return PositionalSet._array(
        _array,
        (values) => transform(_decode(values)),
        minimum: _minimum,
        maximum: _maximum,
      );
    }
    return PositionalSet._tuple(
      _bindings,
      (values) => transform(_decode(values)),
    );
  }

  raw.PositionalParameters get _raw {
    final array = _array;
    if (array != null) {
      return raw.ArrayPositionalParameters(
        parameter: array._raw,
        minimum: _minimum,
        maximum: _maximum,
      );
    }
    return raw.TuplePositionalParameters(
      List.unmodifiable(_bindings.map((binding) => binding._raw)),
    );
  }
}

/// Typed parameter schema for one command.
final class CommandParameters<F, A, C extends CommandContext> {
  /// Creates command parameters.
  const CommandParameters({
    required this.flags,
    required this.positional,
    this.aliases = const {},
  });

  /// Flag decoder.
  final FlagSet<F, C> flags;

  /// Positional decoder.
  final PositionalSet<A, C> positional;

  /// Single-character aliases mapped to internal flag names.
  final Map<String, String> aliases;

  raw.CommandParameters get _raw => raw.CommandParameters(
    flags: {for (final binding in flags._bindings) binding.name: binding._raw},
    aliases: aliases,
    positional: positional._raw,
  );
}

/// A command action with closed input types.
typedef CommandFunction<C extends CommandContext, F, A> =
    FutureOr<void> Function(C context, F flags, A args);

/// Lazily loads a typed command action.
typedef CommandLoader<C extends CommandContext, F, A> =
    FutureOr<CommandFunction<C, F, A>> Function();

/// A typed node in a command routing tree.
sealed class RoutingTarget<C extends CommandContext> {
  const RoutingTarget();

  raw.RoutingTarget get _raw;
}

/// A typed command.
final class Command<C extends CommandContext> extends RoutingTarget<C> {
  const Command._(this._rawCommand);

  final raw.Command _rawCommand;

  @override
  raw.Command get _raw => _rawCommand;
}

raw.CommandFunction _adapt<C extends CommandContext, F, A>(
  CommandParameters<F, A, C> parameters,
  CommandFunction<C, F, A> function,
) {
  return (context, flags, positional) async {
    final typedContext = _commandContext<C>(context);
    final typedFlags = parameters.flags._decode(flags);
    final typedPositional = parameters.positional._decode(positional);
    await function(typedContext, typedFlags, typedPositional);
    return null;
  };
}

/// Builds an eager command.
Command<C> buildCommand<C extends CommandContext, F, A>({
  required CommandDocs docs,
  required CommandParameters<F, A, C> parameters,
  required CommandFunction<C, F, A> func,
}) {
  return Command._(
    raw.buildCommand(
      docs: docs,
      parameters: parameters._raw,
      func: _adapt(parameters, func),
    ),
  );
}

/// Builds a lazy command while preserving its input types.
Command<C> buildLazyCommand<C extends CommandContext, F, A>({
  required CommandDocs docs,
  required CommandParameters<F, A, C> parameters,
  required CommandLoader<C, F, A> loader,
}) {
  return Command._(
    raw.buildLazyCommand(
      docs: docs,
      parameters: parameters._raw,
      loader: () async => _adapt(parameters, await loader()),
    ),
  );
}

/// A typed route map.
final class RouteMap<C extends CommandContext> extends RoutingTarget<C> {
  const RouteMap._(this._rawRouteMap, this._routes);

  final raw.RouteMap _rawRouteMap;
  final Map<String, RoutingTarget<C>> _routes;

  @override
  raw.RouteMap get _raw => _rawRouteMap;
}

RoutingTarget<C> _findTypedTarget<C extends CommandContext>(
  RoutingTarget<C> target,
  raw.RoutingTarget rawTarget,
) {
  if (identical(target._raw, rawTarget)) {
    return target;
  }
  if (target case final RouteMap<C> routeMap) {
    for (final child in routeMap._routes.values) {
      final found = _findTypedTarget(child, rawTarget);
      if (identical(found._raw, rawTarget)) {
        return found;
      }
    }
  }
  throw StateError('The scanned target does not belong to this application');
}

/// Builds a typed route map.
RouteMap<C> buildRouteMap<C extends CommandContext>({
  required RouteMapDocs docs,
  required Map<String, RoutingTarget<C>> routes,
  String? defaultCommand,
  Map<String, String> aliases = const {},
}) {
  return RouteMap._(
    raw.buildRouteMap(
      docs: docs,
      routes: {for (final entry in routes.entries) entry.key: entry.value._raw},
      defaultCommand: defaultCommand,
      aliases: aliases,
    ),
    Map.unmodifiable(routes),
  );
}

/// Immutable route selection supplied to integrations.
final class RouteScanResult<C extends CommandContext> {
  RouteScanResult._(this._raw, RoutingTarget<C> root)
    : target = _findTypedTarget(root, _raw.target),
      unprocessedInputs = List.unmodifiable(_raw.unprocessedInputs),
      prefix = List.unmodifiable(_raw.prefix),
      rootLevel = _raw.rootLevel;

  final raw.RouteScanResult _raw;

  /// Selected command or route map.
  final RoutingTarget<C> target;

  /// Inputs not consumed while selecting [target].
  final List<String> unprocessedInputs;

  /// Executable and route names consumed by the scanner.
  final List<String> prefix;

  /// Whether [target] is the application root.
  final bool rootLevel;
}

/// ANSI color support calculated independently for each process stream.
typedef AnsiColorByStream = raw.AnsiColorByStream;

/// Localized application text and error formatters.
typedef ApplicationText = raw.ApplicationText;

/// Arguments passed to application lifecycle hooks.
final class ApplicationHookArguments {
  /// Creates immutable application hook arguments.
  const ApplicationHookArguments({
    required this.context,
    required this.text,
    required this.ansiColorByStream,
    this.exitCode,
  });

  /// Process and locale available before a command context is loaded.
  final ApplicationContext context;

  /// Localized text selected for this run.
  final ApplicationText text;

  /// ANSI support for stdout and stderr.
  final AnsiColorByStream ansiColorByStream;

  /// Intended exit code, available to end hooks.
  final int? exitCode;
}

/// Arguments passed to command lifecycle hooks.
final class CommandHookArguments<C extends CommandContext> {
  /// Creates immutable command hook arguments.
  const CommandHookArguments({
    required this.context,
    required this.result,
    required this.text,
    required this.ansiColorByStream,
    this.exitCode,
  });

  /// Context created for the selected command.
  final C context;

  /// Immutable route selection.
  final RouteScanResult<C> result;

  /// Localized text selected for this run.
  final ApplicationText text;

  /// ANSI support for stdout and stderr.
  final AnsiColorByStream ansiColorByStream;

  /// Intended command exit code, available to command-end hooks.
  final int? exitCode;
}

/// Arguments passed to an integration application flag.
final class ApplicationFlagArguments<C extends CommandContext> {
  const ApplicationFlagArguments._({
    required this.context,
    required this.application,
    required this.result,
    required this.text,
    required this.ansiColorByStream,
    required this._additionalFlags,
  });

  /// Process and locale for this run.
  final ApplicationContext context;

  /// Application being invoked.
  final Application<C> application;

  /// Immutable route selection.
  final RouteScanResult<C> result;

  /// Localized text selected for this run.
  final ApplicationText text;

  /// ANSI support for stdout and stderr.
  final AnsiColorByStream ansiColorByStream;
  final List<raw.AdditionalFlagDocumentation> _additionalFlags;

  /// Writes help for the selected target using this run's formatting state.
  void writeHelp({
    bool includeHidden = false,
    raw.DocumentationConfiguration? formatting,
  }) {
    final defaults = application._raw.config.documentation;
    final resolvedFormatting = raw.DocumentationConfig(
      alwaysShowHelpAllFlag:
          formatting?.alwaysShowHelpAllFlag ?? defaults.alwaysShowHelpAllFlag,
      useAliasInUsageLine:
          formatting?.useAliasInUsageLine ?? defaults.useAliasInUsageLine,
      onlyRequiredInUsageLine:
          formatting?.onlyRequiredInUsageLine ??
          defaults.onlyRequiredInUsageLine,
      caseStyle: formatting?.caseStyle ?? defaults.caseStyle,
      disableAnsiColor:
          formatting?.disableAnsiColor ?? defaults.disableAnsiColor,
    );
    context.process.stdout.write(
      result._raw.target.formatHelp(
        raw.HelpFormattingArguments(
          prefix: result._raw.prefix,
          config: resolvedFormatting,
          text: text,
          includeLegacyHelpFlag: false,
          includeArgumentEscapeSequenceFlag:
              application._raw.config.scanner.allowArgumentEscapeSequence,
          includeHidden: includeHidden,
          aliases: result._raw.aliases.byStyle(resolvedFormatting.caseStyle),
          additionalFlags: _additionalFlags,
          ansiColor: ansiColorByStream.stdout,
        ),
      ),
    );
  }
}

/// Ordered lifecycle callbacks for an integration.
final class LifecycleHooks<C extends CommandContext> {
  /// Creates lifecycle callbacks.
  const LifecycleHooks({
    this.appStart,
    this.commandStart,
    this.commandEnd,
    this.appEnd,
  });

  /// Runs before route scanning.
  final FutureOr<void> Function(ApplicationHookArguments arguments)? appStart;

  /// Runs after context loading and before command argument parsing.
  final FutureOr<void> Function(CommandHookArguments<C> arguments)?
  commandStart;

  /// Runs after command execution.
  final FutureOr<void> Function(CommandHookArguments<C> arguments)? commandEnd;

  /// Runs after application-flag or command execution.
  final FutureOr<void> Function(ApplicationHookArguments arguments)? appEnd;
}

/// An application-level flag installed by an integration.
final class ApplicationFlag<C extends CommandContext> {
  /// Creates an application flag.
  const ApplicationFlag({
    required this.brief,
    required this.run,
    this.aliases = const [],
    this.hidden = false,
    this.global = false,
    this.complete = true,
    this.defaultForRouteMap = false,
  });

  /// Description shown in help and completion.
  final String brief;

  /// Single-character aliases.
  final List<String> aliases;

  /// Whether normal help and completion hide the flag.
  final bool hidden;

  /// Whether the flag is active below the root target.
  final bool global;

  /// Whether completion proposes the flag.
  final bool complete;

  /// Whether this flag runs for an otherwise-unhandled route map.
  final bool defaultForRouteMap;

  /// Executes the flag.
  final FutureOr<void> Function(ApplicationFlagArguments<C> arguments) run;
}

/// Build-time validation arguments for an integration.
final class IntegrationValidationArguments<C extends CommandContext> {
  /// Creates immutable validation arguments.
  const IntegrationValidationArguments({
    required this.root,
    required this.configuration,
  });

  /// Typed root target.
  final RoutingTarget<C> root;

  /// Fully resolved application configuration.
  final ResolvedApplicationConfiguration configuration;
}

/// A named application integration.
final class CliIntegration<C extends CommandContext> {
  /// Creates an integration.
  const CliIntegration({
    required this.name,
    this.validate,
    this.hooks,
    this.flag,
  });

  /// Canonical integration and long-flag name.
  final String name;

  /// Runs synchronously while the application is built.
  final void Function(IntegrationValidationArguments<C> arguments)? validate;

  /// Ordered lifecycle callbacks.
  final LifecycleHooks<C>? hooks;

  /// Optional application-level flag.
  final ApplicationFlag<C>? flag;
}

/// Version information used by the default version integration.
final class VersionInformation {
  /// Creates static version information.
  const VersionInformation({
    this.currentVersion,
    this.getCurrentVersion,
    this.getLatestVersion,
    this.upgradeCommand,
  }) : assert(
         (currentVersion == null) != (getCurrentVersion == null),
         'Provide exactly one current-version source',
       );

  /// Static current version.
  final String? currentVersion;

  /// Asynchronously resolves the current version.
  final FutureOr<String> Function(ApplicationContext context)?
  getCurrentVersion;

  /// Asynchronously resolves the latest available version.
  final FutureOr<String?> Function(
    ApplicationContext context,
    String currentVersion,
  )?
  getLatestVersion;

  /// Optional command displayed in the update notice.
  final String? upgradeCommand;

  Future<String> _resolve(ApplicationContext context) async =>
      currentVersion ?? await getCurrentVersion!(context);

  raw.VersionInformation get _raw => raw.VersionInformation(
    currentVersion: currentVersion,
    getCurrentVersion: getCurrentVersion == null
        ? null
        : (context) => getCurrentVersion!(_applicationContext(context)),
    getLatestVersion: getLatestVersion == null
        ? null
        : (context, current) =>
              getLatestVersion!(_applicationContext(context), current),
    upgradeCommand: upgradeCommand,
  );
}

/// Lifecycle point used by the version update check.
enum VersionCheckHook {
  /// Before route scanning.
  appStart,

  /// Before the selected command.
  commandStart,

  /// After the selected command.
  commandEnd,

  /// After application execution.
  appEnd,
}

/// Creates the standard help integration.
CliIntegration<C> helpIntegration<C extends CommandContext>({
  String name = 'help',
  String? alias = 'h',
  String brief = 'Show help for this command',
  bool hidden = false,
  bool includeHidden = false,
  bool defaultForRouteMap = true,
  bool complete = true,
  raw.DocumentationConfiguration? formatting,
}) {
  return CliIntegration(
    name: name,
    validate: formatting?.caseStyle == raw.DisplayCaseStyle.convertCamelToKebab
        ? (arguments) {
            if (arguments.configuration.scanner.caseStyle ==
                raw.ScannerCaseStyle.original) {
              throw raw.RouterInternalError(
                'Cannot convert route and flag names on display but scan as original',
              );
            }
          }
        : null,
    flag: ApplicationFlag(
      brief: brief,
      aliases: alias == null ? const [] : [alias],
      hidden: hidden,
      global: true,
      complete: complete,
      defaultForRouteMap: defaultForRouteMap,
      run: (arguments) => arguments.writeHelp(
        includeHidden: includeHidden,
        formatting: formatting,
      ),
    ),
  );
}

Future<void> _checkLatestVersion(
  VersionInformation info,
  ApplicationContext context,
  ApplicationText text,
  AnsiColorByStream ansi,
) async {
  final skip = context.process.readEnv('STRICLI_SKIP_VERSION_CHECK');
  if (skip != null && raw.looseBooleanParser(skip)) {
    return;
  }
  final current = await info._resolve(context);
  final latest = await info.getLatestVersion!(context, current);
  if (latest == null || latest == current) {
    return;
  }
  final message = text.currentVersionIsNotLatest(
    raw.CurrentVersionNotLatestArguments(
      currentVersion: current,
      latestVersion: latest,
      upgradeCommand: info.upgradeCommand,
    ),
  );
  context.process.stderr.write(
    ansi.stderr ? '\x1B[1m\x1B[33m$message\x1B[39m\x1B[22m\n' : '$message\n',
  );
}

/// Creates the standard version flag and optional latest-version hook.
CliIntegration<C> versionIntegration<C extends CommandContext>({
  required VersionInformation info,
  String name = 'version',
  String? alias = 'v',
  String brief = 'Show the current version',
  bool hidden = false,
  bool complete = true,
  VersionCheckHook hook = VersionCheckHook.appStart,
  LifecycleHooks<C> hooks = const LifecycleHooks(),
}) {
  Future<void> appCheck(ApplicationHookArguments arguments) =>
      _checkLatestVersion(
        info,
        arguments.context,
        arguments.text,
        arguments.ansiColorByStream,
      );
  Future<void> commandCheck(CommandHookArguments<C> arguments) =>
      _checkLatestVersion(
        info,
        ApplicationContext(process: arguments.context.process, locale: null),
        arguments.text,
        arguments.ansiColorByStream,
      );
  return CliIntegration(
    name: name,
    hooks: LifecycleHooks(
      appStart:
          hook == VersionCheckHook.appStart && info.getLatestVersion != null
          ? appCheck
          : hooks.appStart,
      commandStart:
          hook == VersionCheckHook.commandStart && info.getLatestVersion != null
          ? commandCheck
          : hooks.commandStart,
      commandEnd:
          hook == VersionCheckHook.commandEnd && info.getLatestVersion != null
          ? commandCheck
          : hooks.commandEnd,
      appEnd: hook == VersionCheckHook.appEnd && info.getLatestVersion != null
          ? appCheck
          : hooks.appEnd,
    ),
    flag: ApplicationFlag(
      brief: brief,
      aliases: alias == null ? const [] : [alias],
      hidden: hidden,
      complete: complete,
      run: (arguments) async {
        arguments.context.process.stdout.write(
          '${await info._resolve(arguments.context)}\n',
        );
      },
    ),
  );
}

/// Application configuration.
final class ApplicationConfiguration {
  /// Creates application configuration.
  const ApplicationConfiguration({
    required this.name,
    this.completion,
    this.determineExitCode,
    this.documentation,
    this.localization,
    this.scanner,
    this.versionInfo,
  });

  /// Executable name.
  final String name;

  /// Completion behavior.
  final raw.CompletionConfiguration? completion;

  /// Maps a command exception to an exit code.
  final int Function(Object? error)? determineExitCode;

  /// Documentation defaults.
  final raw.DocumentationConfiguration? documentation;

  /// Localization behavior.
  final raw.LocalizationConfiguration? localization;

  /// Scanner behavior.
  final raw.ScannerConfiguration? scanner;

  /// Optional default version integration information.
  final VersionInformation? versionInfo;

  raw.ApplicationConfiguration get _raw => raw.ApplicationConfiguration(
    name: name,
    completion: completion,
    determineExitCode: determineExitCode,
    documentation: documentation,
    localization: localization,
    scanner: scanner,
    versionInfo: versionInfo?._raw,
  );
}

/// A typed runnable application.
final class Application<C extends CommandContext> {
  const Application._(this._raw, this.root);

  final raw.Application _raw;

  /// Root routing target.
  final RoutingTarget<C> root;
}

ApplicationContext _applicationContext(raw.RunContext context) =>
    ApplicationContext(process: context.process, locale: context.locale);

/// Builds an application.
Application<C> buildApplication<C extends CommandContext>(
  RoutingTarget<C> root,
  ApplicationConfiguration configuration, {
  List<CliIntegration<C>>? integrations,
}) {
  late Application<C> application;
  final rawIntegrations = integrations?.map((integration) {
    final hooks = integration.hooks;
    final flag = integration.flag;
    return raw.InternalIntegration(
      name: integration.name,
      validate: integration.validate == null
          ? null
          : (rawRoot, resolved) {
              integration.validate!(
                IntegrationValidationArguments(
                  root: root,
                  configuration: resolved,
                ),
              );
            },
      hooks: hooks == null
          ? null
          : raw.InternalLifecycleHooks(
              appStart: hooks.appStart == null
                  ? null
                  : (context, arguments) => hooks.appStart!(
                      ApplicationHookArguments(
                        context: _applicationContext(context),
                        text: arguments.text,
                        ansiColorByStream: arguments.ansiColorByStream,
                        exitCode: arguments.exitCode,
                      ),
                    ),
              commandStart: hooks.commandStart == null
                  ? null
                  : (context, arguments) => hooks.commandStart!(
                      CommandHookArguments(
                        context: _commandContext<C>(context),
                        result: RouteScanResult._(arguments.result, root),
                        text: arguments.text,
                        ansiColorByStream: arguments.ansiColorByStream,
                        exitCode: arguments.exitCode,
                      ),
                    ),
              commandEnd: hooks.commandEnd == null
                  ? null
                  : (context, arguments) => hooks.commandEnd!(
                      CommandHookArguments(
                        context: _commandContext<C>(context),
                        result: RouteScanResult._(arguments.result, root),
                        text: arguments.text,
                        ansiColorByStream: arguments.ansiColorByStream,
                        exitCode: arguments.exitCode,
                      ),
                    ),
              appEnd: hooks.appEnd == null
                  ? null
                  : (context, arguments) => hooks.appEnd!(
                      ApplicationHookArguments(
                        context: _applicationContext(context),
                        text: arguments.text,
                        ansiColorByStream: arguments.ansiColorByStream,
                        exitCode: arguments.exitCode,
                      ),
                    ),
            ),
      flag: flag == null
          ? null
          : raw.InternalApplicationFlag(
              documentation: raw.AdditionalFlagDocumentation(
                name: integration.name,
                brief: flag.brief,
                aliases: List.unmodifiable(flag.aliases),
                hidden: flag.hidden,
                global: flag.global,
                complete: flag.complete,
              ),
              defaultForRouteMap: flag.defaultForRouteMap,
              run: (context, rawApplication, arguments) => flag.run(
                ApplicationFlagArguments._(
                  context: _applicationContext(context),
                  application: application,
                  result: RouteScanResult._(arguments.result, root),
                  text: arguments.text,
                  ansiColorByStream: arguments.ansiColorByStream,
                  additionalFlags: arguments.additionalFlags,
                ),
              ),
            ),
    );
  }).toList();
  final rawApplication = raw.buildApplication(
    root._raw,
    configuration._raw,
    integrations: rawIntegrations,
  );
  application = Application._(rawApplication, root);
  return application;
}

/// Runs an application and returns its intended exit code.
Future<int> runApplication<C extends CommandContext>(
  Application<C> app,
  List<String> inputs,
  RunContext<C> context,
) {
  return raw.runApplication(app._raw, inputs, context._raw);
}

/// Runs an application and assigns its process exit code.
Future<void> run<C extends CommandContext>(
  Application<C> app,
  List<String> inputs,
  RunContext<C> context,
) {
  return raw.run(app._raw, inputs, context._raw);
}

/// Computes completion proposals.
Future<List<raw.InputCompletion>> proposeCompletions<C extends CommandContext>(
  Application<C> app,
  List<String> inputs,
  RunContext<C> context,
) {
  return raw.proposeCompletions(app._raw, inputs, context._raw);
}

/// Context-aware identity parser.
String stringParser<C extends CommandContext>(C context, String input) => input;

/// Context-aware strict boolean parser.
bool booleanParser<C extends CommandContext>(C context, String input) =>
    raw.booleanParser(input);

/// Context-aware loose boolean parser.
bool looseBooleanParser<C extends CommandContext>(C context, String input) =>
    raw.looseBooleanParser(input);

/// Context-aware numeric parser.
num numberParser<C extends CommandContext>(C context, String input) =>
    raw.numberParser(input);
