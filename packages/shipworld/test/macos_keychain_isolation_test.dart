import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/macos.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

/// Signing used one `build.keychain` in the user's home, put it on the
/// user-wide search list, and made it the default keychain. All three are
/// shared, and a self-hosted macOS box runs several runner instances as one
/// user, so a second signing job would `delete-keychain` the one a first was
/// still using. `codesign` then failed with `errSecInternalComponent`, because
/// the private key it had just imported was gone. A hosted runner never saw
/// it, having one job per virtual machine.
void main() {
  test('signing keeps its keychain to itself', () async {
    final executor = _MacExecutor();
    await _sign(executor);

    final security = executor.calls.where((call) => call.first == 'security');

    // Nothing user-wide: the search list and the default keychain belong to
    // every process this user runs, not to this job.
    expect(
      security.where(
        (call) =>
            call.contains('list-keychains') ||
            call.contains('default-keychain'),
      ),
      isEmpty,
      reason: 'a concurrent job shares both of these',
    );

    // No shared name either, or two jobs collide on the file itself.
    final created = security
        .firstWhere((call) => call.contains('create-keychain'))
        .last;
    expect(created, isNot('build.keychain'));
    expect(p.isAbsolute(created), isTrue);

    // Every signature names that keychain, so finding the identity never
    // depends on the search list a concurrent job may have rewritten.
    final signings = executor.calls.where(
      (call) => call.first == 'codesign' && call.contains('--sign'),
    );
    expect(signings, isNotEmpty);
    for (final call in signings) {
      expect(call, containsAllInOrder(<String>['--keychain', created]));
    }

    // And it is taken back down, so a machine that runs thousands of jobs does
    // not accumulate keychains holding a Developer ID.
    expect(
      security.where(
        (call) => call.contains('delete-keychain') && call.contains(created),
      ),
      isNotEmpty,
    );
  });

  test('two signings do not share a keychain', () async {
    final first = _MacExecutor();
    final second = _MacExecutor();
    await _sign(first);
    await _sign(second);

    String keychainOf(_MacExecutor executor) => executor.calls
        .firstWhere((call) => call.contains('create-keychain'))
        .last;

    expect(keychainOf(first), isNot(keychainOf(second)));
  });
}

Future<void> _sign(_MacExecutor executor) async {
  final temporary = await Directory.systemTemp.createTemp(
    'shipworld-keychain-',
  );
  addTearDown(() => temporary.delete(recursive: true));
  final binary = File(p.join(temporary.path, 'tool'));
  await binary.writeAsString('binary');
  final entitlements = File(p.join(temporary.path, 'entitlements.plist'));
  await entitlements.writeAsString('<plist/>');

  await MacosPackagingService(ShipworldContext(process: executor)).sign(
    MacosSignConfig(
      inputPath: binary.path,
      entitlementsPath: entitlements.path,
      skipNotarize: true,
      environment: <String, String>{
        'APPLE_CERTIFICATE': base64Encode(<int>[1, 2, 3]),
        'APPLE_CERTIFICATE_PASSWORD': 'secret',
        'APPLE_DEVELOPER_ID': 'Developer ID Application: Example (ABCDE12345)',
      },
    ),
  );
}

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
