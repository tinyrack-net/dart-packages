import 'dart:io';

import 'package:cliweave/cliweave.dart';
import 'package:path/path.dart' as p;

import '../homebrew.dart';
import '../linux.dart';
import '../macos.dart';
import '../windows.dart';
import 'config.dart';
import 'context.dart';
import 'error.dart';
import 'payload.dart';
import 'release.dart';
import 'version.dart';
import 'version_files.dart';

final _configFlag = ParsedFlag.defaulted<String, ApplicationContext>(
  name: 'config',
  brief: 'Path to shipworld.yaml',
  parse: stringParser,
  defaultValue: 'shipworld.yaml',
);

FlagBinding<String, ApplicationContext> _requiredFlag(
  String name,
  String brief,
) => ParsedFlag.required<String, ApplicationContext>(
  name: name,
  brief: brief,
  parse: stringParser,
);

FlagBinding<String?, ApplicationContext> _optionalFlag(
  String name,
  String brief,
) => ParsedFlag.optional<String, ApplicationContext>(
  name: name,
  brief: brief,
  parse: stringParser,
);

FlagBinding<bool?, ApplicationContext> _booleanFlag(
  String name,
  String brief,
) => BooleanFlag.optional<ApplicationContext>(name: name, brief: brief);

PositionalBinding<String, ApplicationContext> _targetArgument([
  String brief = 'Release target name',
]) => Positional.required<String, ApplicationContext>(
  brief: brief,
  parse: stringParser,
  placeholder: 'target',
);

final class _CliLogger implements ShipworldLogger {
  const _CliLogger(this.process);

  final RunProcess process;

  @override
  void info(String message) => process.stdout.write('$message\n');

  @override
  void progress(String message) => process.stdout.write('$message\n');
}

ShipworldContext _context(CommandContext context) {
  return ShipworldContext(
    environment: Map<String, String>.unmodifiable(Platform.environment),
    logger: _CliLogger(context.process),
  );
}

Future<({ShipworldConfig config, ReleaseTargetConfig target})> _loadTarget(
  String configPath,
  String targetName,
) async {
  final config = await loadShipworldConfig(configPath);
  return (config: config, target: config.target(targetName));
}

ArtifactPayload _payload(
  ReleaseTargetConfig target,
  String input,
  String? launcher,
) {
  final configured = target.payload;
  final resolvedLauncher =
      launcher ?? configured?.launcher ?? target.product?.executable;
  if (resolvedLauncher == null) {
    throw ShipworldException(
      'Target ${target.name} must configure payload.launcher or product',
      code: 'invalid_config',
    );
  }
  return switch (configured?.kind ?? PayloadKind.executable) {
    PayloadKind.executable => ExecutablePayload(
      executablePath: input,
      executableName: resolvedLauncher,
    ),
    PayloadKind.directory => DirectoryPayload(
      directoryPath: input,
      launcherRelativePath: resolvedLauncher,
    ),
  };
}

final _prepareCommand = buildCommand(
  docs: const CommandDocs(brief: 'Prepare an atomic release commit'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_booleanFlag('dryRun', 'Report changes without writing'))
        .map((values) => (config: values.$1, dryRun: values.$2)),
    positional: PositionalSet.array(
      Positional.required<String, ApplicationContext>(
        brief: 'Target and bump, for example cliweave=patch',
        parse: stringParser,
        placeholder: 'target=bump',
      ),
      minimum: 1,
    ),
  ),
  func: (context, flags, args) async {
    final config = await loadShipworldConfig(flags.config);
    final bumps = <String, ReleaseType>{};
    for (final value in args) {
      final parts = value.split('=');
      if (parts.length != 2 || parts.any((part) => part.isEmpty)) {
        throw ShipworldException(
          'Invalid release selection: $value',
          code: 'invalid_argument',
        );
      }
      bumps[parts.first] = parseReleaseType(parts.last);
    }
    final result = await ReleaseService(
      config: config,
      context: _context(context),
    ).prepare(bumps: bumps, dryRun: flags.dryRun == true);
    for (final target in result.targets) {
      context.process.stdout.write(
        '${result.dryRun ? 'Would prepare' : 'Prepared'} '
        '${target.name} ${target.version} (${target.tag})\n',
      );
    }
  },
);

final _finalizeCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Create signed tags from verified remote HEAD',
  ),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_booleanFlag('push', 'Atomically push created tags'))
        .map((values) => (config: values.$1, push: values.$2)),
    positional: PositionalSet.array(_targetArgument(), minimum: 1),
  ),
  func: (context, flags, args) async {
    final config = await loadShipworldConfig(flags.config);
    final result = await ReleaseService(
      config: config,
      context: _context(context),
    ).finalize(targetNames: [...args], push: flags.push == true);
    context.process.stdout.write(
      'Finalized ${result.tags.join(', ')} at ${result.head}\n',
    );
  },
);

final _verifyCommand = buildCommand(
  docs: const CommandDocs(brief: 'Verify a CI tag against a target version'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag).map((config) => (config: config)),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final config = await loadShipworldConfig(flags.config);
    final tag = await ReleaseService(
      config: config,
      context: _context(context),
    ).verify(args.target);
    context.process.stdout.write('Verified $tag\n');
  },
);

final _msixCommand = buildCommand(
  docs: const CommandDocs(brief: 'Build an MSIX from a prebuilt payload'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_requiredFlag('input', 'Executable or directory payload path'))
        .and(_requiredFlag('output', 'Output .msix path'))
        .and(_requiredFlag('packageRoot', 'MSIX staging directory'))
        .and(_requiredFlag('arch', 'MSIX architecture: x64 or arm64'))
        .and(_optionalFlag('launcher', 'Payload launcher override'))
        .map((values) {
          final (((((config, input), output), packageRoot), arch), launcher) =
              values;
          return (
            config: config,
            input: input,
            output: output,
            packageRoot: packageRoot,
            arch: arch,
            launcher: launcher,
          );
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final loaded = await _loadTarget(flags.config, args.target);
    final target = loaded.target;
    final product = target.product;
    final windows = target.windows;
    if (product == null || windows == null) {
      throw ShipworldException(
        'Target ${target.name} must configure product and windows',
        code: 'invalid_config',
      );
    }
    final env = _context(context).environment;
    String envValue(String name) {
      final value = env[name];
      if (value == null || value.trim().isEmpty) {
        throw ShipworldException(
          '$name is required to build Windows MSIX packages',
          code: 'missing_credential',
        );
      }
      return value;
    }

    final identityEnvironment = windows.identityEnvironment;
    final displayNameEnv = identityEnvironment.displayName;
    final version = await readPubspecVersion(
      target.versionPath(loaded.config.repoRoot),
    );
    final result = await WindowsPackagingService(_context(context))
        .buildPackage(
          arch: parseMsixArchitecture(flags.arch),
          payload: _payload(
            target,
            flags.input,
            flags.launcher ?? windows.executable,
          ),
          config: MsixConfig(
            applicationId: windows.applicationId,
            displayName: product.displayName,
            description: product.description,
            executableName: windows.executable,
            backgroundColor: windows.backgroundColor,
          ),
          identity: MsixIdentity(
            identityName: envValue(identityEnvironment.name),
            publisher: envValue(identityEnvironment.publisher),
            publisherDisplayName: envValue(
              identityEnvironment.publisherDisplayName,
            ),
            displayName: displayNameEnv == null ? null : env[displayNameEnv],
          ),
          version: version,
          repoRoot: loaded.config.repoRoot,
          outputPath: flags.output,
          packageRoot: flags.packageRoot,
        );
    context.process.stdout.write('Built ${result.outputPath}\n');
  },
);

final _msixBundleCommand = buildCommand(
  docs: const CommandDocs(brief: 'Bundle architecture-specific MSIX packages'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_requiredFlag('packageDir', 'Directory containing .msix packages'))
        .and(_requiredFlag('output', 'Output .msixbundle path'))
        .and(_requiredFlag('workingDirectory', 'Temporary bundle directory'))
        .map((values) {
          final (((config, packageDir), output), workingDirectory) = values;
          return (
            config: config,
            packageDir: packageDir,
            output: output,
            workingDirectory: workingDirectory,
          );
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final loaded = await _loadTarget(flags.config, args.target);
    final version = await readPubspecVersion(
      loaded.target.versionPath(loaded.config.repoRoot),
    );
    final output = await WindowsPackagingService(_context(context)).buildBundle(
      repoRoot: loaded.config.repoRoot,
      version: version,
      packageDir: flags.packageDir,
      outputPath: flags.output,
      workingDirectory: flags.workingDirectory,
    );
    context.process.stdout.write('Built $output\n');
  },
);

final _macosSignCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Sign and optionally notarize a macOS payload',
  ),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_requiredFlag('input', 'Executable or .app path'))
        .and(_optionalFlag('entitlements', 'Entitlements path override'))
        .and(_booleanFlag('appBundle', 'Treat input as a Flutter .app bundle'))
        .and(
          _booleanFlag(
            'skipNotarize',
            'Use ad-hoc signing without notarization',
          ),
        )
        .map((values) {
          final ((((config, input), entitlements), appBundle), skipNotarize) =
              values;
          return (
            config: config,
            input: input,
            entitlements: entitlements,
            appBundle: appBundle,
            skipNotarize: skipNotarize,
          );
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final loaded = await _loadTarget(flags.config, args.target);
    final configured = loaded.target.macos?.entitlements;
    final entitlements =
        flags.entitlements ??
        (configured == null
            ? null
            : loaded.target.targetPath(
                loaded.config.repoRoot,
                configured,
                'macos entitlements',
              ));
    if (entitlements == null) {
      throw ShipworldException(
        'Target ${loaded.target.name} must configure macos.entitlements',
        code: 'invalid_config',
      );
    }
    await MacosPackagingService(_context(context)).sign(
      MacosSignConfig(
        inputPath: flags.input,
        entitlementsPath: entitlements,
        skipNotarize: flags.skipNotarize == true,
        isAppBundle: flags.appBundle == true,
        environment: _context(context).environment,
      ),
    );
    context.process.stdout.write('Signed ${flags.input}\n');
  },
);

final _macosArchiveCommand = buildCommand(
  docs: const CommandDocs(brief: 'Archive a signed macOS application'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_requiredFlag('input', 'Signed .app path'))
        .and(_requiredFlag('output', 'Output zip path'))
        .map((values) {
          final ((config, input), output) = values;
          return (config: config, input: input, output: output);
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    await _loadTarget(flags.config, args.target);
    final output = await MacosPackagingService(
      _context(context),
    ).archive(appPath: flags.input, outputPath: flags.output);
    context.process.stdout.write('Archived $output\n');
  },
);

final _appImageCommand = buildCommand(
  docs: const CommandDocs(brief: 'Build an AppImage from a prebuilt payload'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_requiredFlag('input', 'Executable or directory payload path'))
        .and(_requiredFlag('output', 'Output AppImage path'))
        .and(_requiredFlag('arch', 'AppImage architecture'))
        .and(_optionalFlag('tool', 'Explicit appimagetool path'))
        .and(_optionalFlag('launcher', 'Payload launcher override'))
        .map((values) {
          final (((((config, input), output), arch), tool), launcher) = values;
          return (
            config: config,
            input: input,
            output: output,
            arch: arch,
            tool: tool,
            launcher: launcher,
          );
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final loaded = await _loadTarget(flags.config, args.target);
    final target = loaded.target;
    final product = target.product;
    final linux = target.linux;
    if (product == null || linux == null) {
      throw ShipworldException(
        'Target ${target.name} must configure product and linux',
        code: 'invalid_config',
      );
    }
    final arch = flags.arch;
    final env = _context(context).environment;
    await LinuxPackagingService(_context(context)).build(
      repoRoot: loaded.config.repoRoot,
      payload: _payload(target, flags.input, flags.launcher),
      config: AppImageConfig(
        name: product.name,
        displayName: product.displayName,
        iconPath: p.normalize(
          p.join(loaded.config.repoRoot, target.root, linux.icon),
        ),
        categories: linux.categories,
        terminal: linux.terminal,
      ),
      outputPath: flags.output,
      arch: arch,
      appImageToolPath:
          flags.tool ??
          env['APPIMAGETOOL_PATH'] ??
          'appimagetool-$arch.AppImage',
    );
    context.process.stdout.write('Built ${flags.output}\n');
  },
);

typedef _LinuxPackageFlags = ({
  String config,
  String input,
  String output,
  String arch,
  String? tool,
  String? launcher,
  String? release,
});

Command<ApplicationContext> _linuxPackageCommand(LinuxPackageFormat format) =>
    buildCommand<ApplicationContext, _LinuxPackageFlags, ({String target})>(
      docs: CommandDocs(
        brief: 'Build a ${format.packagerName} package from a prebuilt payload',
      ),
      parameters: CommandParameters(
        flags: FlagSet.one(_configFlag)
            .and(_requiredFlag('input', 'Executable or directory payload path'))
            .and(_requiredFlag('output', 'Output ${format.packagerName} path'))
            .and(_requiredFlag('arch', 'Package architecture'))
            .and(_optionalFlag('tool', 'Explicit nfpm path'))
            .and(_optionalFlag('launcher', 'Payload launcher override'))
            .and(_optionalFlag('release', 'Packaging revision override'))
            .map((values) {
              final (
                (((((config, input), output), arch), tool), launcher),
                release,
              ) = values;
              return (
                config: config,
                input: input,
                output: output,
                arch: arch,
                tool: tool,
                launcher: launcher,
                release: release,
              );
            }),
        positional: PositionalSet.one(
          _targetArgument(),
        ).map((target) => (target: target)),
      ),
      func: (context, flags, args) async {
        final loaded = await _loadTarget(flags.config, args.target);
        final target = loaded.target;
        final product = target.product;
        final linux = target.linux;
        if (product == null || linux == null) {
          throw ShipworldException(
            'Target ${target.name} must configure product and linux',
            code: 'invalid_config',
          );
        }
        final maintainer = linux.maintainer;
        if (maintainer == null) {
          throw ShipworldException(
            'Target ${target.name} must configure linux.maintainer',
            code: 'invalid_config',
          );
        }
        final version = (await readPubspecVersion(
          target.versionPath(loaded.config.repoRoot),
        )).split('+').first;
        final targetRoot = p.join(loaded.config.repoRoot, target.root);
        final env = _context(context).environment;
        final artifact = await LinuxPackagingService(_context(context))
            .buildPackage(
              repoRoot: loaded.config.repoRoot,
              payload: _payload(target, flags.input, flags.launcher),
              config: LinuxPackageConfig(
                name: product.name,
                displayName: product.displayName,
                description: product.description,
                executableName: product.executable,
                appId: linux.appId ?? product.name,
                version: version,
                architecture: LinuxArchitecture.parse(flags.arch),
                maintainer: maintainer,
                categories: linux.categories,
                terminal: linux.terminal,
                icons: <LinuxIconAsset>[
                  for (final icon in linux.icons)
                    LinuxIconAsset(
                      size: icon.size,
                      sourcePath: p.normalize(p.join(targetRoot, icon.path)),
                    ),
                ],
                release:
                    flags.release ??
                    (format == LinuxPackageFormat.rpm
                        ? linux.rpm.release
                        : '1'),
                prefix: linux.prefix,
                launcherStyle: linux.launcherStyle == 'wrapper'
                    ? LinuxLauncherStyle.wrapper
                    : LinuxLauncherStyle.symlink,
                homepage: product.homepage,
                license: linux.license,
                vendor: linux.vendor,
                section: linux.deb.section,
                group: linux.rpm.group,
                depends: format == LinuxPackageFormat.deb
                    ? linux.deb.depends
                    : linux.rpm.requires,
                recommends: format == LinuxPackageFormat.deb
                    ? linux.deb.recommends
                    : linux.rpm.recommends,
                conflicts: format == LinuxPackageFormat.deb
                    ? linux.deb.conflicts
                    : linux.rpm.conflicts,
              ),
              format: format,
              outputPath: flags.output,
              nfpmToolPath: flags.tool ?? env['NFPM_PATH'] ?? 'nfpm',
            );
        context.process.stdout.write('Built $artifact\n');
      },
    );

final _debCommand = _linuxPackageCommand(LinuxPackageFormat.deb);
final _rpmCommand = _linuxPackageCommand(LinuxPackageFormat.rpm);

final _formulaCommand = buildCommand(
  docs: const CommandDocs(brief: 'Generate a Homebrew Formula'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(
          _requiredFlag(
            'artifactsDir',
            'Directory containing release artifacts',
          ),
        )
        .and(_requiredFlag('output', 'Output Formula path'))
        .and(
          _optionalFlag(
            'versionedOutput',
            'Optional output path for a versioned Formula',
          ),
        )
        .map((values) {
          final (((config, artifactsDir), output), versionedOutput) = values;
          return (
            config: config,
            artifactsDir: artifactsDir,
            output: output,
            versionedOutput: versionedOutput,
          );
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final loaded = await _loadTarget(flags.config, args.target);
    final target = loaded.target;
    final product = target.product;
    final homebrew = target.homebrew;
    if (product == null ||
        product.homepage == null ||
        product.repository == null ||
        homebrew == null) {
      throw ShipworldException(
        'Target ${target.name} must configure product homepage/repository '
        'and homebrew',
        code: 'invalid_config',
      );
    }
    final version = (await readPubspecVersion(
      target.versionPath(loaded.config.repoRoot),
    )).split('+').first;
    final artifactsDir = flags.artifactsDir;
    final payload = target.payload?.kind ?? PayloadKind.executable;
    final extension = homebrewArtifactExtension(payload);
    final artifacts = <HomebrewArtifact>[];
    for (final entry in const [
      ('macos', 'arm64'),
      ('macos', 'x64'),
      ('linux', 'arm64'),
      ('linux', 'x64'),
    ]) {
      final fileName =
          '${homebrew.artifactPrefix}-${entry.$1}-${entry.$2}$extension';
      final filePath = p.join(artifactsDir, fileName);
      artifacts.add(
        HomebrewArtifact(
          platform: entry.$1,
          architecture: entry.$2,
          url:
              'https://github.com/${product.repository}/releases/download/'
              '${target.renderTag(version)}/$fileName',
          sha256: await calculateSha256(filePath),
          fileName: fileName,
        ),
      );
    }
    HomebrewFormulaConfig formulaConfig({
      required String className,
      bool versioned = false,
    }) {
      return HomebrewFormulaConfig(
        className: className,
        description: product.description,
        homepage: product.homepage!,
        version: version,
        executableName: product.executable,
        payload: payload,
        versioned: versioned,
      );
    }

    final output = flags.output;
    final formula = generateConfigurableHomebrewFormula(
      config: formulaConfig(className: homebrew.formulaClass),
      artifacts: artifacts,
    );
    await Directory(p.dirname(output)).create(recursive: true);
    await File(output).writeAsString(formula);

    final versionedOutput = flags.versionedOutput;
    if (versionedOutput == null) {
      context.process.stdout.write('Generated $output\n');
      return;
    }

    final classVersion = version.replaceAll(RegExp('[^0-9A-Za-z]'), '');
    final versionedFormula = generateConfigurableHomebrewFormula(
      config: formulaConfig(
        className: '${homebrew.formulaClass}AT$classVersion',
        versioned: true,
      ),
      artifacts: artifacts,
    );
    await Directory(p.dirname(versionedOutput)).create(recursive: true);
    await File(versionedOutput).writeAsString(versionedFormula);
    context.process.stdout.write('Generated $output and $versionedOutput\n');
  },
);

final _caskCommand = buildCommand(
  docs: const CommandDocs(brief: 'Generate a Homebrew Cask'),
  parameters: CommandParameters(
    flags: FlagSet.one(_configFlag)
        .and(_requiredFlag('archive', 'Signed macOS application archive'))
        .and(_requiredFlag('url', 'Public archive URL'))
        .and(_requiredFlag('output', 'Output Cask path'))
        .map((values) {
          final (((config, archive), url), output) = values;
          return (config: config, archive: archive, url: url, output: output);
        }),
    positional: PositionalSet.one(
      _targetArgument(),
    ).map((target) => (target: target)),
  ),
  func: (context, flags, args) async {
    final loaded = await _loadTarget(flags.config, args.target);
    final target = loaded.target;
    final product = target.product;
    if (product == null || product.homepage == null) {
      throw ShipworldException(
        'Target ${target.name} must configure product homepage',
        code: 'invalid_config',
      );
    }
    final version = (await readPubspecVersion(
      target.versionPath(loaded.config.repoRoot),
    )).split('+').first;
    final cask = generateHomebrewCask(
      token: product.name,
      version: version,
      sha256: await calculateSha256(flags.archive),
      url: flags.url,
      appName: product.displayName,
      // The archive contains the built bundle, whose name is the Flutter or
      // Xcode product name rather than the name shown to the user.
      bundleName: target.macos?.bundleName ?? product.executable,
      description: product.description,
      homepage: product.homepage!,
      bundleId: target.macos?.bundleId,
      minimumMacosVersion: target.macos?.minimumVersion,
      repository: product.repository,
    );
    await File(flags.output).writeAsString(cask);
    context.process.stdout.write('Generated ${flags.output}\n');
  },
);

Application<ApplicationContext> _buildShipworldApplication() {
  final releaseRoutes = buildRouteMap(
    docs: const RouteMapDocs(brief: 'Prepare and finalize releases'),
    routes: {
      'prepare': _prepareCommand,
      'finalize': _finalizeCommand,
      'verify': _verifyCommand,
    },
  );
  final packageRoutes = buildRouteMap(
    docs: const RouteMapDocs(brief: 'Build desktop distribution artifacts'),
    routes: {
      'windows': buildRouteMap(
        docs: const RouteMapDocs(brief: 'Windows packaging'),
        routes: {'msix': _msixCommand, 'bundle': _msixBundleCommand},
      ),
      'macos': buildRouteMap(
        docs: const RouteMapDocs(brief: 'macOS signing and archives'),
        routes: {'sign': _macosSignCommand, 'archive': _macosArchiveCommand},
      ),
      'linux': buildRouteMap(
        docs: const RouteMapDocs(brief: 'Linux packaging'),
        routes: {
          'appimage': _appImageCommand,
          'deb': _debCommand,
          'rpm': _rpmCommand,
        },
      ),
      'homebrew': buildRouteMap(
        docs: const RouteMapDocs(brief: 'Homebrew metadata'),
        routes: {'formula': _formulaCommand, 'cask': _caskCommand},
      ),
    },
  );
  return buildApplication(
    buildRouteMap(
      docs: const RouteMapDocs(
        brief: 'Release and desktop packaging for Dart and Flutter',
      ),
      routes: {'release': releaseRoutes, 'package': packageRoutes},
    ),
    ApplicationConfiguration(
      name: 'shipworld',
      scanner: const ScannerConfiguration(
        caseStyle: ScannerCaseStyle.allowKebabForCamel,
      ),
    ),
  );
}

/// Runs the shipworld command-line application.
Future<int> runShipworld(List<String> args) async {
  final process = RunProcess(
    stdout: StdioWriteStream(stdout),
    stderr: StdioWriteStream(stderr),
  );
  try {
    await run(
      _buildShipworldApplication(),
      args,
      RunContext.direct(ApplicationContext(process: process)),
    );
  } on ShipworldException catch (error) {
    stderr.writeln(error.message);
    return 1;
  }
  return process.exitCode ?? 0;
}
