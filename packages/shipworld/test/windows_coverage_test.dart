// Exercises the Windows SDK-tool discovery in `_findWindowsSdkTool`, which is
// guarded by `if (!Platform.isWindows) throw` — so these tests (which drive
// the real directory scan against a fabricated SDK tree, without a *_PATH
// override) only run, and only cover those lines, on a Windows runner.
@TestOn('windows')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/shipworld.dart';
import 'package:shipworld/windows.dart';
import 'package:test/test.dart';

const _config = MsixConfig(
  applicationId: 'Example',
  displayName: 'Example',
  description: 'Example application',
  executableName: 'example.exe',
);

const _identity = MsixIdentity(
  identityName: 'example.app',
  publisher: 'CN=Example',
  publisherDisplayName: 'Example',
);

Matcher _throwsMessage(Pattern pattern) {
  return throwsA(predicate((Object? error) => '$error'.contains(pattern)));
}

/// Executor that records inherited calls and, when it observes a
/// `makepri createconfig` invocation, materializes the requested config file so
/// the post-build cleanup path deletes it.
final class _RecordingExecutor implements ProcessExecutor {
  final inheritedCalls = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<int> runInherited(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    inheritedCalls.add([executable, ...arguments]);

    if (arguments.contains('createconfig')) {
      final index = arguments.indexOf('/cf');
      if (index != -1 && index + 1 < arguments.length) {
        await File(arguments[index + 1]).writeAsString('<priconfig />');
      }
    }

    return 0;
  }
}

Future<Directory> _createFakeSdk() async {
  final base = await Directory.systemTemp.createTemp('shipworld-sdk-');
  // Nest the SDK under the conventional "Windows Kits/10/bin" layout so the
  // returned directory can be supplied as a ProgramFiles(x86) root.
  final bin = Directory(p.join(base.path, 'Windows Kits', '10', 'bin'));

  // Multiple version directories to exercise the natural-order comparator's
  // numeric, non-numeric, and prefix-length branches.
  for (final version in const [
    '10.0.22000.0',
    '10.0.22000',
    '10.0.19041.0',
    'preview',
  ]) {
    await Directory(p.join(bin.path, version)).create(recursive: true);
  }

  // makepri is found through the direct <version>/<arch> candidate lookup.
  final makePriDir = Directory(p.join(bin.path, '10.0.22000.0', 'x64'));
  await makePriDir.create(recursive: true);
  await File(p.join(makePriDir.path, 'makepri.exe')).writeAsString('');

  // makeappx lives at the bin root, so it is only found by the recursive
  // fallback search after the direct candidate lookup fails.
  await File(p.join(bin.path, 'makeappx.exe')).writeAsString('');

  return base;
}

void main() {
  group('parseMsixArchitecture', () {
    test('returns supported architectures unchanged', () {
      expect(parseMsixArchitecture('x64'), 'x64');
      expect(parseMsixArchitecture('arm64'), 'arm64');
    });

    test('rejects unsupported architectures', () {
      expect(
        () => parseMsixArchitecture('mips'),
        _throwsMessage('Invalid MSIX architecture: mips'),
      );
    });
  });

  group('convertVersionToMsixVersion build metadata', () {
    test('rejects multi-segment build metadata', () {
      expect(
        () => convertVersionToMsixVersion('1.0.0+1+2'),
        _throwsMessage('Invalid package version'),
      );
    });

    test('rejects non-numeric build metadata', () {
      expect(
        () => convertVersionToMsixVersion('1.0.0+beta'),
        _throwsMessage('Invalid package version'),
      );
    });

    test('rejects build metadata above the MSIX segment ceiling', () {
      expect(
        () => convertVersionToMsixVersion('1.0.0+70000'),
        _throwsMessage('MSIX version segment out of range'),
      );
    });
  });

  test(
    'readMsixIdentityFromEnv falls back to the scoped environment',
    () async {
      final identity = await ShipworldContext(
        environment: const {
          'MSIX_IDENTITY_NAME': 'scoped.app',
          'MSIX_PUBLISHER': 'CN=Scoped',
          'MSIX_PUBLISHER_DISPLAY_NAME': 'Scoped Publisher',
        },
      ).run(() async => readMsixIdentityFromEnv());

      expect(identity.identityName, 'scoped.app');
      expect(identity.publisher, 'CN=Scoped');
      expect(identity.publisherDisplayName, 'Scoped Publisher');
    },
  );

  test('buildPackage rejects prerelease versions', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-prerelease-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final payload = Directory(p.join(temporary.path, 'payload'));
    await payload.create();
    await File(p.join(payload.path, 'example.exe')).writeAsString('binary');

    await expectLater(
      WindowsPackagingService(
        ShipworldContext(
          process: _RecordingExecutor(),
          environment: const {
            'MAKEPRI_PATH': 'makepri-test',
            'MAKEAPPX_PATH': 'makeappx-test',
          },
        ),
      ).buildPackage(
        arch: 'x64',
        payload: DirectoryPayload(
          directoryPath: payload.path,
          launcherRelativePath: 'example.exe',
        ),
        config: _config,
        identity: _identity,
        version: '1.0.0-beta.1',
        repoRoot: temporary.path,
        outputPath: p.join('dist', 'example.msix'),
        packageRoot: p.join('.shipworld', 'msix'),
      ),
      throwsA(
        predicate(
          (Object? error) => '$error'.contains('Prerelease versions cannot'),
        ),
      ),
    );
  });

  test('buildPackage resolves SDK tools by scanning the Windows SDK', () async {
    if (!Platform.isWindows) {
      return;
    }

    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-sdk-build-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final sdk = await _createFakeSdk();
    addTearDown(() => sdk.delete(recursive: true));

    final payload = Directory(p.join(temporary.path, 'payload'));
    await payload.create();
    await File(p.join(payload.path, 'example.exe')).writeAsString('binary');

    // Pre-create the package root so the pre-build cleanup deletes it.
    await Directory(
      p.join(temporary.path, '.shipworld', 'msix'),
    ).create(recursive: true);

    final executor = _RecordingExecutor();
    final result =
        await WindowsPackagingService(
          ShipworldContext(
            process: executor,
            environment: {
              // Lower-cased key forces the case-insensitive env lookup path.
              // Points at a nonexistent dir so the first SDK root is skipped.
              'windowssdkdir': p.join(temporary.path, 'missing-sdk'),
              'ProgramFiles': p.join(temporary.path, 'ignored-pf'),
              // The real SDK is discovered under the ProgramFiles(x86) root.
              'ProgramFiles(x86)': sdk.path,
            },
          ),
        ).buildPackage(
          arch: 'arm64',
          payload: DirectoryPayload(
            directoryPath: payload.path,
            launcherRelativePath: 'example.exe',
          ),
          config: _config,
          identity: _identity,
          version: '1.2.3',
          repoRoot: temporary.path,
          outputPath: p.join('dist', 'example.msix'),
          packageRoot: p.join('.shipworld', 'msix'),
        );

    expect(result.outputPath, p.join(temporary.path, 'dist', 'example.msix'));
    // makepri is resolved to the version/arch candidate; makeappx via fallback.
    expect(p.basename(executor.inheritedCalls.first.first), 'makepri.exe');
    expect(p.basename(executor.inheritedCalls.last.first), 'makeappx.exe');
    expect(
      await File(p.join(result.packageRoot, 'AppxManifest.xml')).readAsString(),
      contains('ProcessorArchitecture="arm64"'),
    );
    // The generated priconfig.xml is removed after makepri runs.
    expect(
      File(p.join(result.packageRoot, 'priconfig.xml')).existsSync(),
      isFalse,
    );
  });

  test('buildPackage reports a missing SDK tool', () async {
    if (!Platform.isWindows) {
      return;
    }

    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-missing-tool-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final payload = Directory(p.join(temporary.path, 'payload'));
    await payload.create();
    await File(p.join(payload.path, 'example.exe')).writeAsString('binary');

    await expectLater(
      WindowsPackagingService(
        ShipworldContext(
          process: _RecordingExecutor(),
          // No tool overrides and no SDK roots -> the search finds nothing.
          environment: const {},
        ),
      ).buildPackage(
        arch: 'x64',
        payload: DirectoryPayload(
          directoryPath: payload.path,
          launcherRelativePath: 'example.exe',
        ),
        config: _config,
        identity: _identity,
        version: '1.2.3',
        repoRoot: temporary.path,
        outputPath: p.join('dist', 'example.msix'),
        packageRoot: p.join('.shipworld', 'msix'),
      ),
      throwsA(predicate((Object? error) => '$error'.contains('was not found'))),
    );
  });

  group('buildBundle', () {
    test('throws when no packages are present', () async {
      final temporary = await Directory.systemTemp.createTemp(
        'shipworld-empty-bundle-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      await Directory(p.join(temporary.path, 'packages')).create();

      await expectLater(
        WindowsPackagingService(
          ShipworldContext(
            process: _RecordingExecutor(),
            environment: const {'MAKEAPPX_PATH': 'makeappx-test'},
          ),
        ).buildBundle(
          repoRoot: temporary.path,
          version: '1.2.3',
          packageDir: 'packages',
          outputPath: p.join('dist', 'example.msixbundle'),
          workingDirectory: p.join('.shipworld', 'bundle'),
        ),
        throwsA(
          predicate((Object? error) => '$error'.contains('No .msix packages')),
        ),
      );
    });

    test('bundles the discovered MSIX packages', () async {
      final temporary = await Directory.systemTemp.createTemp(
        'shipworld-bundle-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final packages = Directory(p.join(temporary.path, 'packages'));
      await packages.create();
      await File(p.join(packages.path, 'example-x64.msix')).writeAsString('a');
      await File(
        p.join(packages.path, 'example-arm64.msix'),
      ).writeAsString('b');
      // A non-.msix file is ignored by the discovery filter.
      await File(p.join(packages.path, 'notes.txt')).writeAsString('ignore');

      final executor = _RecordingExecutor();
      final output =
          await WindowsPackagingService(
            ShipworldContext(
              process: executor,
              environment: const {'MAKEAPPX_PATH': 'makeappx-test'},
            ),
          ).buildBundle(
            repoRoot: temporary.path,
            version: '1.2.3',
            packageDir: 'packages',
            outputPath: p.join('dist', 'example.msixbundle'),
            workingDirectory: p.join('.shipworld', 'bundle'),
          );

      expect(output, p.join(temporary.path, 'dist', 'example.msixbundle'));
      expect(executor.inheritedCalls.single.first, 'makeappx-test');
      expect(executor.inheritedCalls.single, contains('bundle'));
      expect(executor.inheritedCalls.single, contains('1.2.3.0'));

      final bundleInput = Directory(
        p.join(temporary.path, '.shipworld', 'bundle'),
      );
      expect(
        File(p.join(bundleInput.path, 'example-x64.msix')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(bundleInput.path, 'example-arm64.msix')).existsSync(),
        isTrue,
      );
    });
  });
}
