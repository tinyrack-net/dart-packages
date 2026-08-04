import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'context.dart';
import 'error.dart';
import 'payload.dart';
import 'process.dart';

/// Product metadata used to stage an AppImage.
final class AppImageConfig {
  const AppImageConfig({
    required this.name,
    required this.displayName,
    required this.iconPath,
    required this.categories,
    this.terminal = false,
  });

  final String name;
  final String displayName;
  final String iconPath;
  final List<String> categories;
  final bool terminal;
}

String _desktopEntry(AppImageConfig config, String launcher) =>
    '''
[Desktop Entry]
Name=${config.displayName}
Exec=$launcher %F
Icon=${config.name}
Type=Application
Categories=${config.categories.join(';')};
Terminal=${config.terminal}
''';

String _appRun(String launcherRelativePath) =>
    '''
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\${0}")")"
exec "\${HERE}/usr/bin/$launcherRelativePath" "\$@"
''';

Future<void> _makeExecutable(String path) async {
  if (Platform.isWindows) {
    return;
  }

  await runChecked('chmod', ['755', path]);
}

/// Builds an AppImage from a prebuilt [payload].
Future<void> buildAppImage({
  required String repoRoot,
  required ArtifactPayload payload,
  required AppImageConfig config,
  required String outputPath,
  required String arch,
  required String appImageToolPath,
}) async {
  final appDir = p.join(repoRoot, '.shipworld', 'appimage', config.name);
  final artifactPath = p.join(repoRoot, outputPath);

  final appDirectory = Directory(appDir);

  if (appDirectory.existsSync()) {
    await appDirectory.delete(recursive: true);
  }

  await Directory(p.join(appDir, 'usr/bin')).create(recursive: true);
  await Directory(p.dirname(artifactPath)).create(recursive: true);
  await payload.stage(p.join(appDir, 'usr/bin'));
  await _makeExecutable(
    p.join(appDir, 'usr/bin', payload.launcherRelativePath),
  );

  await File(
    p.join(appDir, '${config.name}.desktop'),
  ).writeAsString(_desktopEntry(config, payload.launcherRelativePath));

  // The desktop entry's Icon= key is extension-agnostic, so the icon keeps its
  // source extension instead of being forced to one format.
  await File(
    config.iconPath,
  ).copy(p.join(appDir, '${config.name}${p.extension(config.iconPath)}'));

  await File(
    p.join(appDir, 'AppRun'),
  ).writeAsString(_appRun(payload.launcherRelativePath));
  await _makeExecutable(p.join(appDir, 'AppRun'));

  stdout.writeln('Building AppImage...');
  await runChecked(
    appImageToolPath,
    ['--appimage-extract-and-run', appDir, artifactPath],
    workingDirectory: repoRoot,
    environment: {'ARCH': arch},
  );
}

/// Distribution package format understood by the packager.
enum LinuxPackageFormat {
  /// Debian package, consumed by `apt` and `dpkg`.
  deb('deb'),

  /// RPM package, consumed by `dnf`, `yum`, and `zypper`.
  rpm('rpm');

  const LinuxPackageFormat(this.packagerName);

  /// Name nfpm uses for this packager.
  final String packagerName;

  /// Parses a format name, rejecting anything unsupported.
  static LinuxPackageFormat parse(String value) {
    for (final format in LinuxPackageFormat.values) {
      if (format.packagerName == value) return format;
    }
    throw ShipworldException(
      'Invalid Linux package format: $value. Must be one of: '
      '${LinuxPackageFormat.values.map((f) => f.packagerName).join(', ')}',
      code: 'invalid_argument',
    );
  }
}

/// Package architecture, named the way nfpm expects it.
enum LinuxArchitecture {
  /// 64-bit x86, published as `amd64` for deb and `x86_64` for rpm.
  amd64('amd64', <String>['amd64', 'x64', 'x86_64']),

  /// 64-bit ARM, published as `arm64` for deb and `aarch64` for rpm.
  arm64('arm64', <String>['arm64', 'aarch64']);

  const LinuxArchitecture(this.nfpmName, this.aliases);

  /// Name nfpm uses, which it maps per packager.
  final String nfpmName;

  /// Spellings accepted from the caller.
  final List<String> aliases;

  /// Parses an architecture spelling, rejecting anything unsupported.
  static LinuxArchitecture parse(String value) {
    for (final architecture in LinuxArchitecture.values) {
      if (architecture.aliases.contains(value)) return architecture;
    }
    throw ShipworldException(
      'Invalid Linux architecture: $value. Must be one of: '
      '${LinuxArchitecture.values.expand((a) => a.aliases).join(', ')}',
      code: 'invalid_argument',
    );
  }
}

/// How the installed package exposes the launcher on `PATH`.
enum LinuxLauncherStyle {
  /// Symlink `/usr/bin/<executable>` at the staged launcher.
  symlink,

  /// Install a shell wrapper that execs the staged launcher.
  wrapper,
}

/// One installed icon in the hicolor theme.
final class LinuxIconAsset {
  /// Creates an icon asset. A [size] of zero installs a scalable icon.
  const LinuxIconAsset({required this.size, required this.sourcePath});

  /// Square pixel size, or zero for a scalable icon.
  final int size;

  /// Absolute path of the source image.
  final String sourcePath;

  /// Directory under `hicolor` this icon installs into.
  String get themeDirectory => size == 0 ? 'scalable' : '${size}x$size';
}

/// Product metadata used to build a deb or rpm.
final class LinuxPackageConfig {
  /// Creates a Linux distribution package configuration.
  const LinuxPackageConfig({
    required this.name,
    required this.displayName,
    required this.description,
    required this.executableName,
    required this.appId,
    required this.version,
    required this.architecture,
    required this.maintainer,
    required this.categories,
    required this.terminal,
    required this.icons,
    this.release = '1',
    this.prefix = '/usr/lib',
    this.launcherStyle = LinuxLauncherStyle.symlink,
    this.homepage,
    this.license,
    this.vendor,
    this.section = 'utils',
    this.group,
    this.depends = const <String>[],
    this.recommends = const <String>[],
    this.conflicts = const <String>[],
  });

  /// Package name.
  final String name;

  /// Human-readable product name.
  final String displayName;

  /// One-line package description.
  final String description;

  /// Command installed on `PATH`.
  final String executableName;

  /// Reverse-DNS identifier naming the desktop entry and icons.
  final String appId;

  /// Package version without build metadata.
  final String version;

  /// Target architecture.
  final LinuxArchitecture architecture;

  /// Package maintainer, as `Name <email>`.
  final String maintainer;

  /// Desktop entry categories.
  final List<String> categories;

  /// Whether the desktop entry launches in a terminal.
  final bool terminal;

  /// Icons installed into the hicolor theme.
  final List<LinuxIconAsset> icons;

  /// Packaging revision, reset whenever [version] changes.
  final String release;

  /// Directory the payload is installed under.
  final String prefix;

  /// How `/usr/bin/<executable>` is provided.
  final LinuxLauncherStyle launcherStyle;

  /// Upstream homepage.
  final String? homepage;

  /// SPDX license identifier, required by rpm.
  final String? license;

  /// Package vendor.
  final String? vendor;

  /// Debian section.
  final String section;

  /// RPM group.
  final String? group;

  /// Hard runtime dependencies.
  final List<String> depends;

  /// Optional runtime dependencies.
  final List<String> recommends;

  /// Packages this one cannot be installed beside.
  final List<String> conflicts;

  /// Directory the payload occupies inside the package.
  String get installDirectory => p.url.join(prefix, name);
}

String _installedDesktopEntry(LinuxPackageConfig config) =>
    '''
[Desktop Entry]
Type=Application
Version=1.5
Name=${config.displayName}
Comment=${config.description}
Exec=/usr/bin/${config.executableName} %U
Icon=${config.appId}
Categories=${config.categories.join(';')};
Terminal=${config.terminal}
StartupWMClass=${config.appId}
''';

String _launcherWrapper(String launcherPath) =>
    '''
#!/bin/sh
exec "$launcherPath" "\$@"
''';

/// Mode installed files receive, as nfpm's numeric `file_info.mode`.
const int _executableMode = 493; // 0o755
const int _dataMode = 420; // 0o644

Map<String, Object?> _nfpmManifest({
  required LinuxPackageConfig config,
  required LinuxPackageFormat format,
  required String stagedRoot,
  required String launcherInstallPath,
  required String desktopPath,
  required List<({LinuxIconAsset icon, String stagedPath})> icons,
  required List<String> payloadFiles,
  required String launcherRelativePath,
  String? wrapperPath,
}) {
  // Every payload file is listed with an explicit mode rather than staged as a
  // tree, so the package does not inherit whatever modes the build host wrote.
  final contents = <Map<String, Object?>>[
    for (final relative in payloadFiles)
      <String, Object?>{
        'src': p.join(stagedRoot, relative),
        'dst': p.url.join(
          config.installDirectory,
          p.url.joinAll(p.split(relative)),
        ),
        'file_info': <String, Object?>{
          'mode': relative == launcherRelativePath
              ? _executableMode
              : _dataMode,
        },
      },
    if (wrapperPath == null)
      <String, Object?>{
        'src': launcherInstallPath,
        'dst': '/usr/bin/${config.executableName}',
        'type': 'symlink',
      }
    else
      <String, Object?>{
        'src': wrapperPath,
        'dst': '/usr/bin/${config.executableName}',
        'file_info': <String, Object?>{'mode': _executableMode},
      },
    <String, Object?>{
      'src': desktopPath,
      'dst': '/usr/share/applications/${config.appId}.desktop',
      'file_info': <String, Object?>{'mode': _dataMode},
    },
    for (final entry in icons)
      <String, Object?>{
        'src': entry.stagedPath,
        'dst':
            '/usr/share/icons/hicolor/${entry.icon.themeDirectory}/apps/'
            '${config.appId}${p.extension(entry.icon.sourcePath)}',
        'file_info': <String, Object?>{'mode': _dataMode},
      },
  ];

  return <String, Object?>{
    'name': config.name,
    'arch': config.architecture.nfpmName,
    'platform': 'linux',
    // Debian orders a pre-release below its final version only when the
    // separator is a tilde, which is not how semver spells it.
    'version': config.version.replaceAll('-', '~'),
    'release': config.release,
    'section': config.section,
    'priority': 'optional',
    'maintainer': config.maintainer,
    'description': config.description,
    if (config.vendor != null) 'vendor': config.vendor,
    if (config.homepage != null) 'homepage': config.homepage,
    if (config.license != null) 'license': config.license,
    if (config.depends.isNotEmpty) 'depends': config.depends,
    if (config.recommends.isNotEmpty) 'recommends': config.recommends,
    if (config.conflicts.isNotEmpty) 'conflicts': config.conflicts,
    'contents': contents,
    if (format == LinuxPackageFormat.rpm && config.group != null)
      'rpm': <String, Object?>{'group': config.group},
  };
}

/// Builds a deb or rpm from a prebuilt [payload] using a caller-supplied nfpm.
///
/// File modes and the `/usr/bin` link are declared in the manifest rather than
/// created on disk, so staging behaves the same on every host.
Future<String> buildLinuxPackage({
  required String repoRoot,
  required ArtifactPayload payload,
  required LinuxPackageConfig config,
  required LinuxPackageFormat format,
  required String outputPath,
  required String nfpmToolPath,
}) async {
  if (format == LinuxPackageFormat.rpm && config.license == null) {
    throw const ShipworldException(
      'rpm packages require a license',
      code: 'invalid_config',
    );
  }

  final workDir = p.join(
    repoRoot,
    '.shipworld',
    format.packagerName,
    config.name,
  );
  final artifactPath = p.join(repoRoot, outputPath);
  final workDirectory = Directory(workDir);
  if (workDirectory.existsSync()) {
    await workDirectory.delete(recursive: true);
  }

  final stagedRoot = p.join(workDir, 'root');
  await Directory(stagedRoot).create(recursive: true);
  await Directory(p.dirname(artifactPath)).create(recursive: true);
  await payload.stage(stagedRoot);

  final desktopPath = p.join(workDir, '${config.appId}.desktop');
  await File(desktopPath).writeAsString(_installedDesktopEntry(config));

  final launcherInstallPath = p.url.join(
    config.installDirectory,
    p.url.joinAll(p.split(payload.launcherRelativePath)),
  );
  String? wrapperPath;
  if (config.launcherStyle == LinuxLauncherStyle.wrapper) {
    wrapperPath = p.join(workDir, config.executableName);
    await File(
      wrapperPath,
    ).writeAsString(_launcherWrapper(launcherInstallPath));
  }

  final stagedIcons = <({LinuxIconAsset icon, String stagedPath})>[];
  for (final icon in config.icons) {
    final stagedPath = p.join(
      workDir,
      'icons',
      '${icon.themeDirectory}${p.extension(icon.sourcePath)}',
    );
    await Directory(p.dirname(stagedPath)).create(recursive: true);
    await File(icon.sourcePath).copy(stagedPath);
    stagedIcons.add((icon: icon, stagedPath: stagedPath));
  }

  final payloadFiles =
      Directory(stagedRoot)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((file) => p.relative(file.path, from: stagedRoot))
          .toList()
        ..sort();

  final manifestPath = p.join(workDir, 'nfpm.json');
  await File(manifestPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      _nfpmManifest(
        config: config,
        format: format,
        stagedRoot: stagedRoot,
        launcherInstallPath: launcherInstallPath,
        desktopPath: desktopPath,
        icons: stagedIcons,
        payloadFiles: payloadFiles,
        launcherRelativePath: payload.launcherRelativePath,
        wrapperPath: wrapperPath,
      ),
    ),
  );

  stdout.writeln('Building ${format.packagerName} package...');
  await runChecked(nfpmToolPath, <String>[
    'package',
    '--config',
    manifestPath,
    '--packager',
    format.packagerName,
    '--target',
    artifactPath,
  ], workingDirectory: repoRoot);
  return artifactPath;
}

/// Context-bound Linux packaging API.
final class LinuxPackagingService {
  const LinuxPackagingService(this.context);

  final ShipworldContext context;

  /// Builds a deb or rpm from a prebuilt payload.
  Future<String> buildPackage({
    required String repoRoot,
    required ArtifactPayload payload,
    required LinuxPackageConfig config,
    required LinuxPackageFormat format,
    required String outputPath,
    required String nfpmToolPath,
  }) {
    return context.run(
      () => buildLinuxPackage(
        repoRoot: repoRoot,
        payload: payload,
        config: config,
        format: format,
        outputPath: outputPath,
        nfpmToolPath: nfpmToolPath,
      ),
    );
  }

  Future<void> build({
    required String repoRoot,
    required ArtifactPayload payload,
    required AppImageConfig config,
    required String outputPath,
    required String arch,
    required String appImageToolPath,
  }) {
    return context.run(
      () => buildAppImage(
        repoRoot: repoRoot,
        payload: payload,
        config: config,
        outputPath: outputPath,
        arch: arch,
        appImageToolPath: appImageToolPath,
      ),
    );
  }
}
