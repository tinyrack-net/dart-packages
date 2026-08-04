import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/homebrew.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

List<HomebrewArtifact> _fullArtifactSet() => [
  HomebrewArtifact(
    platform: 'macos',
    architecture: 'arm64',
    url: 'https://example.com/mac-arm.tar.gz',
    sha256: 'a' * 64,
    fileName: 'tool-macos-arm64',
  ),
  HomebrewArtifact(
    platform: 'macos',
    architecture: 'x64',
    url: 'https://example.com/mac-x64.tar.gz',
    sha256: 'b' * 64,
    fileName: 'tool-macos-x64',
  ),
  HomebrewArtifact(
    platform: 'linux',
    architecture: 'arm64',
    url: 'https://example.com/linux-arm.tar.gz',
    sha256: 'c' * 64,
    fileName: 'tool-linux-arm64',
  ),
  HomebrewArtifact(
    platform: 'linux',
    architecture: 'x64',
    url: 'https://example.com/linux-x64.tar.gz',
    sha256: 'd' * 64,
    fileName: 'tool-linux-x64',
  ),
];

void main() {
  test('calculateSha256 hashes file bytes', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-brew-');
    addTearDown(() => temporary.delete(recursive: true));
    final file = File(p.join(temporary.path, 'payload.bin'));
    await file.writeAsString('hello');

    // Known SHA-256 of the ASCII string "hello".
    expect(
      await calculateSha256(file.path),
      '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
    );
  });

  test('generateConfigurableHomebrewFormula renders every platform', () {
    final formula = generateConfigurableHomebrewFormula(
      config: const HomebrewFormulaConfig(
        className: 'Tool',
        description: 'A tool',
        homepage: 'https://example.com',
        version: '1.2.3',
        executableName: 'tool',
      ),
      artifacts: _fullArtifactSet(),
    );

    expect(formula, contains('class Tool < Formula'));
    expect(formula, contains('desc "A tool"'));
    expect(formula, contains('homepage "https://example.com"'));
    expect(formula, contains('version "1.2.3"'));
    expect(formula, contains('url "https://example.com/mac-arm.tar.gz"'));
    expect(formula, contains('sha256 "${'a' * 64}"'));
    expect(formula, contains('url "https://example.com/mac-x64.tar.gz"'));
    expect(formula, contains('url "https://example.com/linux-x64.tar.gz"'));
    expect(formula, contains('url "https://example.com/linux-arm.tar.gz"'));
    expect(formula, contains('bin.install "tool-macos-arm64" => "tool"'));
    expect(formula, contains('bin.install "tool-macos-x64" => "tool"'));
    expect(formula, contains('bin.install "tool-linux-x64" => "tool"'));
    expect(formula, contains('bin.install "tool-linux-arm64" => "tool"'));
    expect(formula, contains('system "#{bin}/tool", "--version"'));
    // Non-versioned formulas must not emit keg_only.
    expect(formula, isNot(contains('keg_only')));
  });

  test('generateConfigurableHomebrewFormula emits keg_only when versioned', () {
    final formula = generateConfigurableHomebrewFormula(
      config: const HomebrewFormulaConfig(
        className: 'ToolAT1',
        description: 'A pinned tool',
        homepage: 'https://example.com',
        version: '1.0.0',
        executableName: 'tool',
        versioned: true,
      ),
      artifacts: _fullArtifactSet(),
    );

    expect(formula, contains('keg_only :versioned_formula'));
  });

  test('generateHomebrewCask names the built bundle, not the label', () {
    final cask = generateHomebrewCask(
      token: 'example-app',
      version: '2.0.0',
      sha256: 'e' * 64,
      url: 'https://example.com/Example.zip',
      appName: 'Example App',
      bundleName: 'example_app',
      description: 'An example app',
      homepage: 'https://example.com',
    );

    // Naming the display name here produces a cask that installs nothing.
    expect(cask, contains('app "example_app.app"'));
    expect(cask, contains('name "Example App"'));
    expect(cask, isNot(contains('zap')));
    expect(cask, isNot(contains('depends_on')));
    expect(cask, isNot(contains('livecheck')));
  });

  test('generateHomebrewCask renders the optional audit stanzas', () {
    final cask = generateHomebrewCask(
      token: 'example',
      version: '2.0.0',
      sha256: 'e' * 64,
      url: 'https://example.com/Example.zip',
      appName: 'Example',
      bundleName: 'Example',
      description: 'An example app',
      homepage: 'https://example.com',
      bundleId: 'net.example.app',
      minimumMacosVersion: 'ventura',
      repository: 'example/example',
    );

    expect(cask, contains('depends_on macos: ">= :ventura"'));
    expect(cask, contains('strategy :github_latest'));
    expect(cask, contains('"~/Library/Preferences/net.example.app.plist"'));
  });

  test('generateHomebrewCask rejects a token Homebrew would not accept', () {
    expect(
      () => generateHomebrewCask(
        token: 'Example_App',
        version: '2.0.0',
        sha256: 'e' * 64,
        url: 'https://example.com/Example.zip',
        appName: 'Example',
        bundleName: 'Example',
        description: 'An example app',
        homepage: 'https://example.com',
      ),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_config',
        ),
      ),
    );
  });

  test('generateHomebrewCask renders a notarized app cask', () {
    final cask = generateHomebrewCask(
      token: 'example',
      version: '2.0.0',
      sha256: 'e' * 64,
      url: 'https://example.com/Example.zip',
      appName: 'Example',
      bundleName: 'Example',
      description: 'An example app',
      homepage: 'https://example.com',
    );

    expect(cask, contains('cask "example" do'));
    expect(cask, contains('version "2.0.0"'));
    expect(cask, contains('sha256 "${'e' * 64}"'));
    expect(cask, contains('url "https://example.com/Example.zip"'));
    expect(cask, contains('name "Example"'));
    expect(cask, contains('desc "An example app"'));
    expect(cask, contains('homepage "https://example.com"'));
    expect(cask, contains('app "Example.app"'));
  });
}
