import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shipworld/macos.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

final class _MacExecutor implements ProcessExecutor {
  final calls = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add([executable, ...arguments]);
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<int> runInherited(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }
}

/// Bytes that make a fixture look like a Mach-O image to the signer.
final Uint8List _machO = Uint8List.fromList(<int>[
  0xcf,
  0xfa,
  0xed,
  0xfe,
  0,
  0,
  0,
  0,
]);

void main() {
  group('decodeBase64Secret', () {
    final payload = List<int>.generate(180, (index) => index % 251);
    final encoded = base64Encode(payload);

    test('decodes plain single-line base64', () {
      expect(decodeBase64Secret(encoded), payload);
    });

    test('decodes base64 wrapped at 64 columns like the base64 CLI', () {
      final wrapped = RegExp(
        '.{1,64}',
      ).allMatches(encoded).map((match) => match.group(0)).join('\n');

      // Dart's strict decoder rejects this shape outright — the lenient
      // helper must accept it (Node Buffer.from(s, 'base64') semantics the
      // CI secrets were created for).
      expect(() => base64Decode(wrapped), throwsFormatException);
      expect(decodeBase64Secret(wrapped), payload);
    });

    test('decodes base64 with surrounding whitespace and CRLF wrapping', () {
      final wrapped = RegExp(
        '.{1,76}',
      ).allMatches(encoded).map((match) => match.group(0)).join('\r\n');

      expect(decodeBase64Secret(' $wrapped\r\n'), payload);
    });
  });

  test('signs nested Flutter binaries before the app bundle', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-macos-');
    addTearDown(() => temporary.delete(recursive: true));
    final app = Directory(p.join(temporary.path, 'Example.app'));
    final framework = File(
      p.join(app.path, 'Contents', 'Frameworks', 'example.dylib'),
    );
    await framework.parent.create(recursive: true);
    await framework.writeAsBytes(_machO);
    final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
    await entitlements.writeAsString('<plist/>');
    final executor = _MacExecutor();

    await MacosPackagingService(ShipworldContext(process: executor)).sign(
      MacosSignConfig(
        inputPath: app.path,
        entitlementsPath: entitlements.path,
        skipNotarize: true,
        isAppBundle: true,
      ),
    );

    expect(executor.calls.first.last, framework.path);
    expect(
      executor.calls.any(
        (call) => call.contains('--entitlements') && call.last == app.path,
      ),
      isTrue,
    );
    expect(executor.calls.last, contains('--verify'));
  });

  test('signs nested bundles rather than the resources inside them', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-macos-');
    addTearDown(() => temporary.delete(recursive: true));
    final app = Directory(p.join(temporary.path, 'Example.app'));
    final frameworks = p.join(app.path, 'Contents', 'Frameworks');
    // A Flutter application bundle keeps its assets inside App.framework, so
    // anything that sweeps up every file under Frameworks signs hundreds of
    // images. A framework seals its own resources.
    final assetPath = p.join(
      frameworks,
      'App.framework',
      'Versions',
      'A',
      'Resources',
      'flutter_assets',
      'icon.png',
    );
    await Directory(p.dirname(assetPath)).create(recursive: true);
    await File(assetPath).writeAsString('png');
    final dylib = File(p.join(frameworks, 'libplugin.dylib'));
    await dylib.writeAsBytes(_machO);
    final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
    await entitlements.writeAsString('<plist/>');
    final executor = _MacExecutor();

    await MacosPackagingService(ShipworldContext(process: executor)).sign(
      MacosSignConfig(
        inputPath: app.path,
        entitlementsPath: entitlements.path,
        skipNotarize: true,
        isAppBundle: true,
      ),
    );

    final signed = executor.calls
        .where((call) => call.first == 'codesign' && !call.contains('--verify'))
        .map((call) => call.last)
        .toList();

    expect(signed, contains(dylib.path));
    expect(signed, contains(p.join(frameworks, 'App.framework')));
    expect(signed, isNot(contains(assetPath)));
    // The framework is sealed before the application that contains it.
    expect(
      signed.indexOf(p.join(frameworks, 'App.framework')),
      lessThan(signed.indexOf(app.path)),
    );
  });

  test('imports the certificate before signing an app bundle', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-macos-');
    addTearDown(() => temporary.delete(recursive: true));
    final app = Directory(p.join(temporary.path, 'Example.app'));
    final binary = File(p.join(app.path, 'Contents', 'MacOS', 'Example'));
    await binary.parent.create(recursive: true);
    await binary.writeAsBytes(_machO);
    final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
    await entitlements.writeAsString('<plist/>');
    final executor = _MacExecutor();

    await MacosPackagingService(ShipworldContext(process: executor)).sign(
      MacosSignConfig(
        inputPath: app.path,
        entitlementsPath: entitlements.path,
        skipNotarize: true,
        isAppBundle: true,
        environment: {
          'APPLE_CERTIFICATE': base64Encode(<int>[1, 2, 3]),
          'APPLE_CERTIFICATE_PASSWORD': 'secret',
          'APPLE_DEVELOPER_ID': 'Developer ID Application: Example (TEAM12345)',
        },
      ),
    );

    // Without this the keychain holds no identity and codesign fails with
    // "no identity found" against whichever file it reached first.
    expect(
      executor.calls.any(
        (call) => call.first == 'security' && call.contains('import'),
      ),
      isTrue,
    );
    expect(
      executor.calls.any(
        (call) =>
            call.first == 'codesign' &&
            call.contains('Developer ID Application: Example (TEAM12345)'),
      ),
      isTrue,
    );
    expect(
      File(p.join(temporary.path, 'certificate.p12')).existsSync(),
      isFalse,
    );
  });

  test('notarizes and staples a signed app bundle', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-macos-');
    addTearDown(() => temporary.delete(recursive: true));
    final app = Directory(p.join(temporary.path, 'Example.app'));
    final binary = File(p.join(app.path, 'Contents', 'MacOS', 'Example'));
    await binary.parent.create(recursive: true);
    await binary.writeAsBytes(_machO);
    final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
    await entitlements.writeAsString('<plist/>');
    final executor = _MacExecutor();

    await MacosPackagingService(ShipworldContext(process: executor)).sign(
      MacosSignConfig(
        inputPath: app.path,
        entitlementsPath: entitlements.path,
        skipNotarize: false,
        isAppBundle: true,
        environment: {
          'APPLE_CERTIFICATE': base64Encode(<int>[1, 2, 3]),
          'APPLE_CERTIFICATE_PASSWORD': 'secret',
          'APPLE_DEVELOPER_ID': 'Developer ID Application: Example (TEAM12345)',
          'APPLE_NOTARY_KEY_P8_BASE64': base64Encode(<int>[4, 5, 6]),
          'APPLE_NOTARY_KEY_ID': 'KEY123',
          'APPLE_NOTARY_ISSUER_ID': 'ISSUER123',
        },
      ),
    );

    final zipPath = '${app.path}.notarize.zip';
    expect(
      executor.calls.any(
        (call) => call.first == 'ditto' && call.contains(zipPath),
      ),
      isTrue,
    );
    expect(
      executor.calls.any(
        (call) => call.first == 'xcrun' && call.contains('notarytool'),
      ),
      isTrue,
    );
    // Stapling writes the ticket into the bundle so Gatekeeper accepts it
    // without reaching the network.
    expect(
      executor.calls.any(
        (call) => call.first == 'xcrun' && call.contains('stapler'),
      ),
      isTrue,
    );
    expect(File(zipPath).existsSync(), isFalse);
    expect(File('AuthKey.p8').existsSync(), isFalse);
  });
}
