import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'context.dart';
import 'error.dart';
import 'process.dart';

/// Product-neutral macOS signing inputs.
final class MacosSignConfig {
  const MacosSignConfig({
    required this.inputPath,
    required this.entitlementsPath,
    this.skipNotarize = false,
    this.isAppBundle = false,
    this.environment,
  });

  final String inputPath;
  final String entitlementsPath;
  final bool skipNotarize;
  final bool isAppBundle;
  final Map<String, String>? environment;
}

Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int maxRetries = 2,
  Duration delay = const Duration(seconds: 30),
}) async {
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (_) {
      if (attempt == maxRetries) {
        rethrow;
      }

      stdout.writeln(
        'Attempt $attempt/$maxRetries failed, '
        'retrying in ${delay.inSeconds}s...',
      );
      await Future<void>.delayed(delay);
    }
  }

  throw StateError('Unreachable');
}

Future<void> _tryRun(String executable, List<String> args) async {
  try {
    await runChecked(executable, args);
  } on ShipworldException {
    // Ignore failures (e.g. no signature or attributes exist).
  }
}

/// Decodes a base64 secret leniently, like Node's `Buffer.from(s, 'base64')`
/// which the pre-cutover TS signing flow used: CI secrets produced with the
/// `base64` CLI wrap at 64/76 columns, and Dart's strict decoder rejects the
/// embedded newlines ("Invalid padding character").
List<int> decodeBase64Secret(String value) {
  return base64Decode(value.replaceAll(RegExp(r'\s'), ''));
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);

  if (file.existsSync()) {
    await file.delete();
  }
}

/// Installs the Developer ID certificate into a throwaway keychain.
///
/// Returns the identity `codesign` should use: the configured Developer ID
/// when a certificate was supplied, or `-` for ad-hoc signing. The caller is
/// responsible for [disposeSigningIdentity].
Future<String> _installSigningIdentity(Map<String, String> env) async {
  final appleCertificate = env['APPLE_CERTIFICATE'];
  final appleCertificatePassword = env['APPLE_CERTIFICATE_PASSWORD'];
  final appleDeveloperId = env['APPLE_DEVELOPER_ID'];

  if (appleCertificate == null || appleCertificate.isEmpty) {
    stdout.writeln('No Apple Certificate found. Performing ad-hoc signing...');
    return '-';
  }
  if (appleCertificatePassword == null ||
      appleCertificatePassword.isEmpty ||
      appleDeveloperId == null ||
      appleDeveloperId.isEmpty) {
    throw const ShipworldException(
      'APPLE_CERTIFICATE_PASSWORD and APPLE_DEVELOPER_ID are required '
      'when APPLE_CERTIFICATE is set',
    );
  }

  stdout.writeln('Importing Apple Certificate...');
  await File('certificate.p12')
      .writeAsBytes(decodeBase64Secret(appleCertificate));

  await _tryRun('security', ['delete-keychain', 'build.keychain']);
  await runChecked('security', [
    'create-keychain',
    '-p',
    'actions',
    'build.keychain',
  ]);

  final listResult = await runChecked('security', ['list-keychains']);
  final keychainList = listResult.stdout
      .split('\n')
      .map((keychain) => keychain.trim())
      .where((keychain) => keychain.isNotEmpty)
      .toList();

  if (!keychainList.contains('build.keychain')) {
    await runChecked('security', [
      'list-keychains',
      '-s',
      ...keychainList,
      'build.keychain',
    ]);
  }

  await runChecked('security', ['default-keychain', '-s', 'build.keychain']);
  await runChecked('security', [
    'unlock-keychain',
    '-p',
    'actions',
    'build.keychain',
  ]);
  await runChecked('security', [
    'import',
    'certificate.p12',
    '-k',
    'build.keychain',
    '-P',
    appleCertificatePassword,
    '-T',
    '/usr/bin/codesign',
  ]);
  await runChecked('security', [
    'set-key-partition-list',
    '-S',
    'apple-tool:,apple:,codesign:',
    '-s',
    '-k',
    'actions',
    'build.keychain',
  ]);
  return appleDeveloperId;
}

/// Removes the decoded certificate written by [_installSigningIdentity].
Future<void> _disposeSigningIdentity() => _deleteIfExists('certificate.p12');

/// Submits [archivePath] to the notary service and waits for the verdict.
Future<void> _notarize({
  required String archivePath,
  required Map<String, String> env,
  required bool skipNotarize,
}) async {
  final keyBase64 = env['APPLE_NOTARY_KEY_P8_BASE64'];
  if (keyBase64 == null || keyBase64.isEmpty) {
    stdout.writeln('No Notary API Key found. Skipping notarization.');
    return;
  }
  if (skipNotarize) {
    stdout.writeln('Notarization skipped (--skip-notarize flag).');
    return;
  }

  final keyId = env['APPLE_NOTARY_KEY_ID'];
  final issuerId = env['APPLE_NOTARY_ISSUER_ID'];
  if (keyId == null || keyId.isEmpty || issuerId == null || issuerId.isEmpty) {
    throw const ShipworldException(
      'APPLE_NOTARY_KEY_ID and APPLE_NOTARY_ISSUER_ID are required '
      'when APPLE_NOTARY_KEY_P8_BASE64 is set',
    );
  }

  stdout.writeln('Notarizing macOS payload...');
  await File('AuthKey.p8').writeAsBytes(decodeBase64Secret(keyBase64));
  try {
    await withRetry(
      () => runChecked('xcrun', [
        'notarytool',
        'submit',
        archivePath,
        '--key',
        'AuthKey.p8',
        '--key-id',
        keyId,
        '--issuer',
        issuerId,
        '--wait',
      ]),
    );
  } finally {
    await _deleteIfExists('AuthKey.p8');
  }
}

Future<void> signMacosExecutable({
  required String inputPath,
  required String entitlementsPath,
  required bool skipNotarize,
  Map<String, String>? environment,
}) async {
  final env = environment ?? currentShipworldEnvironment;
  final resolvedExecutablePath = inputPath;

  stdout.writeln('Removing existing signature if any...');
  await _tryRun('codesign', ['--remove-signature', resolvedExecutablePath]);

  stdout.writeln('Removing extended attributes if any...');
  await _tryRun('xattr', ['-cr', resolvedExecutablePath]);

  final identity = await _installSigningIdentity(env);
  try {
    if (identity == '-') {
      await runChecked('codesign', ['--sign', '-', resolvedExecutablePath]);
      return;
    }

    stdout.writeln('Signing macOS binary...');
    await runChecked('codesign', [
      '--force',
      '--options',
      'runtime',
      '--entitlements',
      entitlementsPath,
      '--sign',
      identity,
      resolvedExecutablePath,
    ]);

    final zipPath = '$resolvedExecutablePath.zip';
    if (env['APPLE_NOTARY_KEY_P8_BASE64']?.isNotEmpty ?? false) {
      await runChecked('zip', ['-j', zipPath, resolvedExecutablePath]);
    }
    await _notarize(archivePath: zipPath, env: env, skipNotarize: skipNotarize);
  } finally {
    await _disposeSigningIdentity();
  }
}

/// Signs a native executable or Flutter `.app` payload.
///
/// Flutter bundles are signed from their nested binaries outward before the
/// root application receives the hardened-runtime signature.
/// Leading words that identify a Mach-O image, in both byte orders, plus the
/// universal-binary magic.
const Set<int> _machOMagics = {
  0xfeedface, // 32-bit
  0xcefaedfe,
  0xfeedfacf, // 64-bit
  0xcffaedfe,
  0xcafebabe, // universal
  0xbebafeca,
};

/// Whether [file] begins with a Mach-O magic word.
///
/// Nested code is identified by what it is rather than by where it sits: a
/// Flutter bundle keeps hundreds of images under `Frameworks`, and signing
/// those individually is both pointless and slow.
///
/// A file that cannot be read is left to throw. Skipping it would leave
/// unsigned code inside the bundle, which surfaces much later as an opaque
/// notarization rejection.
Future<bool> _isMachO(File file) async {
  final handle = await file.open();
  try {
    final header = await handle.read(4);
    if (header.length < 4) return false;
    final word =
        (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];
    return _machOMagics.contains(word);
  } finally {
    await handle.close();
  }
}

/// Extensions of nested bundles, which seal their own contents.
const Set<String> _bundleExtensions = {
  '.framework',
  '.app',
  '.bundle',
  '.xpc',
  '.appex',
};

Future<void> signMacosPayload(MacosSignConfig config) async {
  if (!config.isAppBundle) {
    return signMacosExecutable(
      inputPath: config.inputPath,
      entitlementsPath: config.entitlementsPath,
      skipNotarize: config.skipNotarize,
      environment: config.environment,
    );
  }

  final env = config.environment ?? currentShipworldEnvironment;
  final identity = await _installSigningIdentity(env);
  try {
    final nested = <String>[];

    await for (final entity in Directory(
      config.inputPath,
    ).list(recursive: true, followLinks: false)) {
      final isNested = switch (entity) {
        File() => await _isMachO(entity),
        // Nested bundles seal their own resources, so signing the bundle
        // covers everything inside it.
        Directory() => _bundleExtensions.contains(p.extension(entity.path)),
        _ => false,
      };
      if (isNested) {
        nested.add(entity.path);
      }
    }

    // Deepest first, so an inner bundle is sealed before the one containing it.
    nested.sort((left, right) => right.length.compareTo(left.length));

    for (final path in nested) {
      await runChecked('codesign', [
        '--force',
        '--options',
        'runtime',
        '--sign',
        identity,
        path,
      ]);
    }

    await runChecked('codesign', [
      '--force',
      '--options',
      'runtime',
      '--entitlements',
      config.entitlementsPath,
      '--sign',
      identity,
      config.inputPath,
    ]);

    if (identity != '-' &&
        (env['APPLE_NOTARY_KEY_P8_BASE64']?.isNotEmpty ?? false) &&
        !config.skipNotarize) {
      // The notary service takes an archive, and stapling writes the ticket
      // into the bundle so Gatekeeper accepts it without network access.
      final zipPath = '${config.inputPath}.notarize.zip';
      await runChecked('ditto', [
        '-c',
        '-k',
        '--keepParent',
        config.inputPath,
        zipPath,
      ]);
      try {
        await _notarize(
          archivePath: zipPath,
          env: env,
          skipNotarize: config.skipNotarize,
        );
        await runChecked('xcrun', ['stapler', 'staple', config.inputPath]);
      } finally {
        await _deleteIfExists(zipPath);
      }
    } else {
      await _notarize(
        archivePath: config.inputPath,
        env: env,
        skipNotarize: config.skipNotarize,
      );
    }
  } finally {
    await _disposeSigningIdentity();
  }

  await runChecked('codesign', [
    '--verify',
    '--deep',
    '--strict',
    config.inputPath,
  ]);
}

/// Creates a metadata-preserving zip for a signed macOS application.
Future<String> archiveMacosApp({
  required String appPath,
  required String outputPath,
}) async {
  await runChecked('ditto', [
    '-c',
    '-k',
    '--keepParent',
    '--sequesterRsrc',
    appPath,
    outputPath,
  ]);

  return outputPath;
}

/// Context-bound macOS signing and archive API.
final class MacosPackagingService {
  const MacosPackagingService(this.context);

  final ShipworldContext context;

  Future<void> sign(MacosSignConfig config) {
    return context.run(() => signMacosPayload(config));
  }

  Future<String> archive({
    required String appPath,
    required String outputPath,
  }) {
    return context.run(
      () => archiveMacosApp(appPath: appPath, outputPath: outputPath),
    );
  }
}
