import 'dart:io';

import 'package:crypto/crypto.dart';

import 'config.dart';
import 'error.dart';

/// One downloadable Homebrew artifact.
final class HomebrewArtifact {
  const HomebrewArtifact({
    required this.platform,
    required this.architecture,
    required this.url,
    required this.sha256,
    required this.fileName,
  });

  final String platform;
  final String architecture;
  final String url;
  final String sha256;
  final String fileName;
}

/// Product metadata for a generated Homebrew Formula.
final class HomebrewFormulaConfig {
  const HomebrewFormulaConfig({
    required this.className,
    required this.description,
    required this.homepage,
    required this.version,
    required this.executableName,
    this.payload = PayloadKind.executable,
    this.versioned = false,
  });

  final String className;
  final String description;
  final String homepage;
  final String version;
  final String executableName;

  /// Shape of the downloaded artifact.
  ///
  /// [PayloadKind.executable] is one bare file installed directly as the
  /// binary. [PayloadKind.directory] is an archive holding the executable and
  /// the libraries it loads at run time, which must stay next to it.
  final PayloadKind payload;

  final bool versioned;
}

/// Archive suffix a Homebrew artifact carries for [kind].
///
/// A bare executable is downloaded as-is; a bundle has to be an archive so
/// that its sibling libraries survive the trip.
String homebrewArtifactExtension(PayloadKind kind) => switch (kind) {
  PayloadKind.executable => '',
  PayloadKind.directory => '.tar.gz',
};

/// Renders the branch chain that installs one bare executable per platform.
///
/// Only the combinations that were actually built appear, so a Formula never
/// references an artifact the release does not carry.
String _executableInstall(
  HomebrewFormulaConfig config,
  HomebrewArtifact? Function(String platform, String architecture) find,
) {
  const conditions = <(String, String, String)>[
    ('macos', 'arm64', 'OS.mac? && Hardware::CPU.arm?'),
    ('macos', 'x64', 'OS.mac? && Hardware::CPU.intel?'),
    ('linux', 'x64', 'OS.linux? && Hardware::CPU.intel?'),
    ('linux', 'arm64', 'OS.linux? && Hardware::CPU.arm?'),
  ];
  final branches = <String>[];
  for (final (platform, architecture, condition) in conditions) {
    final artifact = find(platform, architecture);
    if (artifact == null) continue;
    final keyword = branches.isEmpty ? 'if' : 'elsif';
    branches.add(
      '    $keyword $condition\n'
      '      bin.install "${artifact.fileName}" '
      '=> "${config.executableName}"',
    );
  }
  return '${branches.join('\n')}\n    end';
}

Future<String> calculateSha256(String filePath) async {
  final content = await File(filePath).readAsBytes();

  return sha256.convert(content).toString();
}

/// Renders a product-neutral Formula for the supplied artifacts.
///
/// Only the platforms and architectures present in [artifacts] are rendered,
/// so a product that does not ship, say, a Linux arm64 build produces a
/// Formula that simply does not claim to support it.
String generateConfigurableHomebrewFormula({
  required HomebrewFormulaConfig config,
  required List<HomebrewArtifact> artifacts,
}) {
  if (artifacts.isEmpty) {
    throw const ShipworldException(
      'A Homebrew Formula needs at least one artifact',
      code: 'invalid_config',
    );
  }

  HomebrewArtifact? find(String platform, String architecture) {
    for (final item in artifacts) {
      if (item.platform == platform && item.architecture == architecture) {
        return item;
      }
    }
    return null;
  }

  /// Renders `on_macos`/`on_linux` with only the architectures that exist.
  String? platformBlock(String platform) {
    final arm = find(platform, 'arm64');
    final intel = find(platform, 'x64');
    if (arm == null && intel == null) return null;
    final blocks = <String>[
      // Homebrew's DSL names them by CPU family, not by the architecture
      // strings this package uses everywhere else.
      if (intel != null)
        '''
    on_intel do
      url "${intel.url}"
      sha256 "${intel.sha256}"
    end''',
      if (arm != null)
        '''
    on_arm do
      url "${arm.url}"
      sha256 "${arm.sha256}"
    end''',
    ];
    return '  on_$platform do\n${blocks.join('\n')}\n  end';
  }

  final platforms = <String>[
    for (final platform in const ['macos', 'linux']) ?platformBlock(platform),
  ];
  final kegOnly = config.versioned ? '\n  keg_only :versioned_formula\n' : '';
  // Homebrew strips the single top-level directory of the archive, so the
  // staging directory holds the bundle's own `bin/` and `lib/`. The launcher
  // is symlinked rather than copied because its RPATH is relative to the real
  // path of the executable, which keeps `lib/` reachable through the link.
  final install = switch (config.payload) {
    PayloadKind.directory =>
      '''
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/${config.executableName}"''',
    PayloadKind.executable => _executableInstall(config, find),
  };

  return '''
class ${config.className} < Formula
  desc "${config.description}"
  homepage "${config.homepage}"
  version "${config.version}"$kegOnly

${platforms.join('\n\n')}

  def install
$install
  end

  test do
    system "#{bin}/${config.executableName}", "--version"
  end
end
''';
}

/// Renders a Homebrew Cask for a notarized macOS application archive.
///
/// [appName] is the name shown to the user, while [bundleName] is the basename
/// of the `.app` inside the archive. They are usually different, and naming the
/// wrong one produces a cask that installs nothing.
String generateHomebrewCask({
  required String token,
  required String version,
  required String sha256,
  required String url,
  required String appName,
  required String bundleName,
  required String description,
  required String homepage,
  String? bundleId,
  String? minimumMacosVersion,
  String? repository,
}) {
  if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(token)) {
    throw ShipworldException(
      'Invalid Homebrew Cask token: $token. '
      'Tokens may only contain lowercase letters, digits, and hyphens.',
      code: 'invalid_config',
    );
  }
  final dependsOn = minimumMacosVersion == null
      ? ''
      // Homebrew deprecated the string comparison form; the bare symbol
      // already means "this release or newer".
      : '\n  depends_on macos: :$minimumMacosVersion\n';
  final livecheck = repository == null
      ? ''
      : '\n  livecheck do\n'
            '    url :url\n'
            '    strategy :github_latest\n'
            '  end\n';
  final zap = bundleId == null
      ? ''
      : '\n  zap trash: [\n'
            '    "~/Library/Application Support/$bundleName",\n'
            '    "~/Library/Caches/$bundleId",\n'
            '    "~/Library/Preferences/$bundleId.plist",\n'
            '    "~/Library/Saved Application State/$bundleId.savedState",\n'
            '  ]\n';
  return '''
cask "$token" do
  version "$version"
  sha256 "$sha256"

  url "$url"
  name "$appName"
  desc "$description"
  homepage "$homepage"
$livecheck$dependsOn
  app "$bundleName.app"
${zap}end
''';
}
