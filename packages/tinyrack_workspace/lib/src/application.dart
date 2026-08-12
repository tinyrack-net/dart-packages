import 'dart:io';

import 'package:path/path.dart' as p;

import 'coverage_policy.dart';
import 'lcov_merger.dart';
import 'source_policy.dart';

typedef OutputWriter = void Function(Object? value);

/// Runs the reusable workspace-policy command and returns a process exit code.
Future<int> runTinyrackWorkspace(
  List<String> arguments, {
  required OutputWriter out,
  required OutputWriter error,
}) async {
  if (arguments.isEmpty) return _usage(error);
  final command = arguments.first;
  final options = arguments.skip(1).toList(growable: false);
  final root = _option(options, '--root') ?? Directory.current.path;
  switch (command) {
    case 'source-check':
      if (options.any((value) => !value.startsWith('--root='))) {
        return _usage(error);
      }
      final violations = const TinyrackSourcePolicy().verify(root);
      for (final violation in violations) {
        error(violation);
      }
      if (violations.isNotEmpty) return 1;
      out('Tinyrack dependency sources are pinned.');
      return 0;
    case 'coverage-check':
      if (options.any(
        (value) =>
            !value.startsWith('--root=') &&
            !value.startsWith('--scope=') &&
            !value.startsWith('--line=') &&
            !value.startsWith('--branch='),
      )) {
        return _usage(error);
      }
      final line = _percentage(options, '--line', 90, error);
      final branch = _percentage(options, '--branch', 80, error);
      if (line == null || branch == null) return 64;
      final scopes = {
        for (final option in options)
          if (option.startsWith('--scope='))
            option.substring('--scope='.length),
      };
      late final List<String> packages;
      try {
        packages = CoverageWorkspace(root).packageDirectories(scopes: scopes);
      } on UnknownCoverageScope catch (failure) {
        error(failure);
        return 64;
      }
      final policy = CoveragePolicy(
        minimumLineRate: line / 100,
        minimumBranchRate: branch / 100,
      );
      var failed = false;
      for (final directory in packages) {
        final totals = policy.calculate(directory);
        final name = p.basename(directory);
        out(
          '$name: line=${(totals.lineRate * 100).toStringAsFixed(1)}% '
          'branch=${(totals.branchRate * 100).toStringAsFixed(1)}%',
        );
        final failure = policy.validate(name, totals);
        if (failure != null) {
          error(failure);
          failed = true;
        }
      }
      return failed ? 1 : 0;
    case 'coverage-merge':
      if (options.any(
        (value) =>
            !value.startsWith('--input=') && !value.startsWith('--output='),
      )) {
        return _usage(error);
      }
      final inputs = <String>[
        for (final option in options)
          if (option.startsWith('--input='))
            option.substring('--input='.length),
      ];
      final output = _option(options, '--output');
      if (inputs.isEmpty || output == null || output.isEmpty) {
        return _usage(error);
      }
      try {
        const LcovMerger().mergeFiles(inputs, output);
      } on FormatException catch (failure) {
        error(failure);
        return 1;
      } on StateError catch (failure) {
        error(failure);
        return 1;
      }
      out('Merged ${inputs.length} LCOV reports into $output.');
      return 0;
    default:
      return _usage(error);
  }
}

String? _option(List<String> options, String name) {
  final matches = options.where((value) => value.startsWith('$name='));
  return matches.isEmpty ? null : matches.last.substring(name.length + 1);
}

double? _percentage(
  List<String> options,
  String name,
  double defaultValue,
  OutputWriter error,
) {
  final raw = _option(options, name);
  if (raw == null) return defaultValue;
  final value = double.tryParse(raw);
  if (value == null || value < 0 || value > 100) {
    error('$name must be a number from 0 through 100.');
    return null;
  }
  return value;
}

int _usage(OutputWriter error) {
  error(
    'Usage: dart run tinyrack_workspace '
    '<source-check|coverage-check|coverage-merge> '
    '[--root=DIR] [--scope=NAME] [--line=PERCENT] [--branch=PERCENT] '
    '[--input=FILE] [--output=FILE]',
  );
  return 64;
}
