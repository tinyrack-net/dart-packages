import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shipworld/macos.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

/// Configurable fake process boundary.
///
/// Records every invocation and lets individual tests drive error and parsing
/// branches by failing selected commands or returning custom stdout.
final class _FakeExecutor implements ProcessExecutor {
  _FakeExecutor({this.shouldFail});

  final calls = <List<String>>[];

  /// Returns true when the given invocation should exit non-zero.
  final bool Function(String executable, List<String> arguments)? shouldFail;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add([executable, ...arguments]);
    final failed = shouldFail?.call(executable, arguments) ?? false;
    return ProcessResult(0, failed ? 1 : 0, '', '');
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

Future<void> _signWith(_FakeExecutor executor, MacosSignConfig config) {
  return MacosPackagingService(ShipworldContext(process: executor))
      .sign(config);
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
  // The signing flow writes `certificate.p12` / `AuthKey.p8` relative to the
  // current directory and deletes them again; defend against any leftovers if
  // a test aborts unexpectedly.
  tearDown(() async {
    for (final name in ['certificate.p12', 'AuthKey.p8']) {
      final file = File(name);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  });

  group('withRetry', () {
    test('retries once then succeeds', () async {
      var attempts = 0;
      final result = await withRetry<String>(() async {
        attempts++;
        if (attempts < 2) {
          throw StateError('boom');
        }
        return 'ok';
      }, delay: Duration.zero);

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('throws the unreachable guard when maxRetries is zero', () {
      expect(
        withRetry<String>(() async => 'x', maxRetries: 0),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('signMacosExecutable via service (plain binary)', () {
    String certEnvBase64() => base64Encode(<int>[1, 2, 3, 4]);
    String notaryEnvBase64() => base64Encode(<int>[5, 6, 7, 8]);

    test('performs full keychain import, signing, and notarization', () async {
      final temporary = await Directory.systemTemp.createTemp(
        'shipworld-macos-cov-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
      await entitlements.writeAsString('<plist/>');
      final executor = _FakeExecutor();

      await _signWith(
        executor,
        MacosSignConfig(
          inputPath: p.join(temporary.path, 'app.bin'),
          entitlementsPath: entitlements.path,
          environment: {
            'APPLE_CERTIFICATE': certEnvBase64(),
            'APPLE_CERTIFICATE_PASSWORD': 'pw',
            'APPLE_DEVELOPER_ID': 'Developer ID Application: Example',
            'APPLE_NOTARY_KEY_ID': 'KEYID',
            'APPLE_NOTARY_ISSUER_ID': 'ISSUERID',
            'APPLE_NOTARY_KEY_P8_BASE64': notaryEnvBase64(),
          },
        ),
      );

      expect(
        executor.calls.any((call) => call.contains('create-keychain')),
        isTrue,
      );
      expect(executor.calls.any((call) => call.contains('notarytool')), isTrue);
      // The credential files are removed after a successful run.
      expect(File('certificate.p12').existsSync(), isFalse);
      expect(File('AuthKey.p8').existsSync(), isFalse);
    });

    test('throws when certificate is set without required credentials', () {
      final executor = _FakeExecutor();

      expect(
        _signWith(
          executor,
          MacosSignConfig(
            inputPath: 'app.bin',
            entitlementsPath: 'entitlements.plist',
            environment: {
              'APPLE_CERTIFICATE': certEnvBase64(),
              'APPLE_CERTIFICATE_PASSWORD': 'pw',
              'APPLE_DEVELOPER_ID': '',
            },
          ),
        ),
        throwsA(isA<ShipworldException>()),
      );
    });

    test('skips notarization when skipNotarize is set', () async {
      final executor = _FakeExecutor();

      await _signWith(
        executor,
        MacosSignConfig(
          inputPath: 'app.bin',
          entitlementsPath: 'entitlements.plist',
          skipNotarize: true,
          environment: {
            'APPLE_CERTIFICATE': certEnvBase64(),
            'APPLE_CERTIFICATE_PASSWORD': 'pw',
            'APPLE_DEVELOPER_ID': 'Developer ID Application: Example',
            'APPLE_NOTARY_KEY_P8_BASE64': notaryEnvBase64(),
          },
        ),
      );

      expect(
        executor.calls.any((call) => call.contains('notarytool')),
        isFalse,
      );
    });

    test('skips notarization when no notary key is present', () async {
      final executor = _FakeExecutor();

      await _signWith(
        executor,
        MacosSignConfig(
          inputPath: 'app.bin',
          entitlementsPath: 'entitlements.plist',
          environment: {
            'APPLE_CERTIFICATE': certEnvBase64(),
            'APPLE_CERTIFICATE_PASSWORD': 'pw',
            'APPLE_DEVELOPER_ID': 'Developer ID Application: Example',
          },
        ),
      );

      expect(
        executor.calls.any((call) => call.contains('notarytool')),
        isFalse,
      );
    });

    test('throws when notary key lacks key id or issuer id', () {
      final executor = _FakeExecutor();

      expect(
        _signWith(
          executor,
          MacosSignConfig(
            inputPath: 'app.bin',
            entitlementsPath: 'entitlements.plist',
            environment: {
              'APPLE_CERTIFICATE': certEnvBase64(),
              'APPLE_CERTIFICATE_PASSWORD': 'pw',
              'APPLE_DEVELOPER_ID': 'Developer ID Application: Example',
              'APPLE_NOTARY_KEY_P8_BASE64': notaryEnvBase64(),
              'APPLE_NOTARY_KEY_ID': '',
              'APPLE_NOTARY_ISSUER_ID': '',
            },
          ),
        ),
        throwsA(isA<ShipworldException>()),
      );
    });

    test('resolves credentials from the scoped context environment', () async {
      final executor = _FakeExecutor();

      // No config environment: signing falls back to the context-scoped
      // environment (empty here), exercising the ad-hoc branch.
      await _signWith(
        executor,
        const MacosSignConfig(
          inputPath: 'app.bin',
          entitlementsPath: 'entitlements.plist',
        ),
      );

      expect(
        executor.calls.any(
          (call) => call.contains('--sign') && call.contains('-'),
        ),
        isTrue,
      );
    });

    test(
      'falls back to ad-hoc signing and tolerates cleanup failures',
      () async {
        final executor = _FakeExecutor(
          shouldFail: (executable, arguments) =>
              arguments.contains('--remove-signature') || executable == 'xattr',
        );

        await _signWith(
          executor,
          const MacosSignConfig(
            inputPath: 'app.bin',
            entitlementsPath: 'entitlements.plist',
            environment: <String, String>{},
          ),
        );

        expect(
          executor.calls.any(
            (call) => call.contains('--sign') && call.contains('-'),
          ),
          isTrue,
        );
      },
    );
  });

  group('signMacosPayload (app bundle)', () {
    test('signs non-dylib framework payloads', () async {
      final temporary = await Directory.systemTemp.createTemp(
        'shipworld-macos-bundle-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final app = Directory(p.join(temporary.path, 'Example.app'));
      final framework = File(
        p.join(app.path, 'Contents', 'Frameworks', 'Example'),
      );
      await framework.parent.create(recursive: true);
      await framework.writeAsBytes(_machO);
      final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
      await entitlements.writeAsString('<plist/>');
      final executor = _FakeExecutor();

      await _signWith(
        executor,
        MacosSignConfig(
          inputPath: app.path,
          entitlementsPath: entitlements.path,
          skipNotarize: true,
          isAppBundle: true,
          environment: {
            'APPLE_DEVELOPER_ID': 'Developer ID Application: Example',
          },
        ),
      );

      expect(executor.calls.first.last, framework.path);
      expect(executor.calls.last, contains('--verify'));
    });
  });

  group('archiveMacosApp via service', () {
    test('archives the app with ditto and returns the output path', () async {
      final executor = _FakeExecutor();

      final output = await MacosPackagingService(
        ShipworldContext(process: executor),
      ).archive(appPath: 'Example.app', outputPath: 'Example.zip');

      expect(output, 'Example.zip');
      expect(executor.calls.single.first, 'ditto');
    });
  });
}
