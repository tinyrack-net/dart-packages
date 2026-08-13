@Tags(['interop'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartage/src/age.dart';
import 'package:dartage/src/hpke.dart';
import 'package:dartage/src/pq_primitives.dart';
import 'package:dartage/src/primitives.dart';
import 'package:dartage/src/stanza.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Interop tests against the reference `age-encryption` npm package
/// (installed at this package's node_modules), driven via node.
void main() {
  final packageRoot = Directory.current.path;
  final script = p.join(packageRoot, 'test', 'interop', 'age_interop.mjs');

  Future<String> runNode(List<String> args, {String stdinText = ''}) async {
    final process = await Process.start('node', [
      script,
      ...args,
    ], workingDirectory: packageRoot);
    process.stdin.write(stdinText);
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      fail('node ${args.join(' ')} failed ($exitCode): $stderr');
    }
    return stdout;
  }

  Uint8List randomPayload(int size, Random random) {
    return Uint8List.fromList(
      List<int>.generate(size, (_) => random.nextInt(256)),
    );
  }

  test('node and the age-encryption package are available', () async {
    final result = await Process.run('node', ['--version']);
    expect(
      result.exitCode,
      0,
      reason: 'node must be installed for interop tests',
    );
    final keys = await runNode(['keygen']);
    expect(keys.trim().split('\n'), hasLength(2));
  });

  test('TS and Dart derive the same recipient for a Dart identity', () async {
    final identity = X25519Identity.generate();
    final tsRecipient = (await runNode(['recipient', identity.encoded])).trim();
    expect(tsRecipient, (await identity.recipient()).encoded);
  });

  test('Dart derives the same recipient for a TS identity', () async {
    final keys = (await runNode(['keygen'])).trim().split('\n');
    final tsIdentity = keys[0].trim();
    final tsRecipient = keys[1].trim();
    expect(
      (await X25519Identity.parse(tsIdentity).recipient()).encoded,
      tsRecipient,
    );
  });

  test('Dart-encrypt -> TS-decrypt (armored)', () async {
    final random = Random(42);
    final keys = (await runNode(['keygen'])).trim().split('\n');
    final tsIdentity = keys[0].trim();
    final tsRecipient = keys[1].trim();

    for (final size in [0, 1, 100, 65536, 70000]) {
      final plaintext = randomPayload(size, random);
      final encrypter = AgeEncrypter(
        recipients: [parseAgeRecipient(tsRecipient)],
      );
      final armored = AgeArmor.encode(await encrypter.encrypt(plaintext));
      final decrypted = await runNode([
        'decrypt',
        tsIdentity,
      ], stdinText: armored);
      expect(base64Decode(decrypted.trim()), plaintext, reason: 'size $size');
    }
  });

  test('TS-encrypt -> Dart-decrypt (armored)', () async {
    final random = Random(1337);
    final identity = X25519Identity.generate();
    final recipient = (await identity.recipient()).encoded;

    for (final size in [0, 1, 100, 65536, 70000]) {
      final plaintext = randomPayload(size, random);
      final armored = await runNode([
        'encrypt',
        recipient,
      ], stdinText: base64Encode(plaintext));
      final decrypter = AgeDecrypter(identities: [identity]);
      expect(
        await decrypter.decrypt(AgeArmor.decode(armored)),
        plaintext,
        reason: 'size $size',
      );
    }
  });

  test('multi-recipient interop in both directions', () async {
    final random = Random(7);
    final plaintext = randomPayload(5000, random);

    final dartIdentity = X25519Identity.generate();
    final dartRecipient = (await dartIdentity.recipient()).encoded;
    final keys = (await runNode(['keygen'])).trim().split('\n');
    final tsIdentity = keys[0].trim();
    final tsRecipient = keys[1].trim();

    // Dart encrypts to both; TS decrypts with its identity.
    final encrypter = AgeEncrypter(
      recipients: [
        parseAgeRecipient(dartRecipient),
        parseAgeRecipient(tsRecipient),
      ],
    );
    final armored = AgeArmor.encode(await encrypter.encrypt(plaintext));
    final tsDecrypted = await runNode([
      'decrypt',
      tsIdentity,
    ], stdinText: armored);
    expect(base64Decode(tsDecrypted.trim()), plaintext);

    // TS encrypts to both; Dart decrypts with its identity.
    final tsArmored = await runNode([
      'encrypt',
      tsRecipient,
      dartRecipient,
    ], stdinText: base64Encode(plaintext));
    final decrypter = AgeDecrypter(identities: [dartIdentity]);
    expect(await decrypter.decrypt(AgeArmor.decode(tsArmored)), plaintext);
  });

  test('MLKEM768-X25519 interop in both directions', () async {
    final plaintext = randomPayload(70000, Random(99));
    final keys = (await runNode(['hybrid-keygen'])).trim().split('\n');
    final identity = MlKem768X25519Identity.parse(keys[0]);
    final recipient = MlKem768X25519Recipient.parse(keys[1]);
    expect((await identity.recipient()).encoded, recipient.encoded);

    final dartArmored = AgeArmor.encode(
      await AgeEncrypter(recipients: [recipient]).encrypt(plaintext),
    );
    final nodePlaintext = await runNode([
      'decrypt',
      identity.encoded,
    ], stdinText: dartArmored);
    expect(base64Decode(nodePlaintext.trim()), plaintext);

    final nodeArmored = await runNode([
      'encrypt',
      recipient.encoded,
    ], stdinText: base64Encode(plaintext));
    expect(
      await AgeDecrypter(identities: [identity])
          .decrypt(AgeArmor.decode(nodeArmored)),
      plaintext,
    );
  });

  test('scrypt interop in both directions', () async {
    const passphrase = 'correct horse battery staple';
    final plaintext = randomPayload(4096, Random(123));
    final dartArmored = AgeArmor.encode(
      await AgeEncrypter(
        recipients: [ScryptRecipient(passphrase, workFactorLog2: 10)],
      ).encrypt(plaintext),
    );
    final nodePlaintext = await runNode([
      'decrypt-passphrase',
      passphrase,
    ], stdinText: dartArmored);
    expect(base64Decode(nodePlaintext.trim()), plaintext);

    final nodeArmored = await runNode([
      'encrypt-passphrase',
      passphrase,
      '10',
    ], stdinText: base64Encode(plaintext));
    expect(
      await AgeDecrypter(identities: [ScryptIdentity(passphrase)])
          .decrypt(AgeArmor.decode(nodeArmored)),
      plaintext,
    );
  });

  for (final kind in ['tag', 'hybrid-tag']) {
    test(
      '$kind recipient stanza interoperates with a custom identity',
      () async {
        final keys = (await runNode(['$kind-keygen'])).trim().split('\n');
        final plaintext = randomPayload(1000, Random(kind.hashCode));
        final recipient = parseAgeRecipient(keys[1]);
        final armored = AgeArmor.encode(
          await AgeEncrypter(recipients: [recipient]).encrypt(plaintext),
        );
        final nodePlaintext = await runNode([
          'decrypt-tag',
          kind,
          keys[0],
        ], stdinText: armored);
        expect(base64Decode(nodePlaintext.trim()), plaintext);

        final nodeArmored = await runNode([
          'encrypt',
          keys[1],
        ], stdinText: base64Encode(plaintext));
        expect(
          await AgeDecrypter(
            identities: [_TagTestIdentity(kind, _hexToBytes(keys[0]))],
          ).decrypt(AgeArmor.decode(nodeArmored)),
          plaintext,
        );
      },
    );
  }
}

Uint8List _hexToBytes(String value) {
  return Uint8List.fromList([
    for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16),
  ]);
}

BigInt _bigIntFromBytes(List<int> bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

final class _TagTestIdentity implements AgeIdentity {
  _TagTestIdentity(this.kind, this.secretKey);

  final String kind;
  final Uint8List secretKey;

  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    final hybrid = kind == 'hybrid-tag';
    final type = hybrid ? 'mlkem768p256tag' : 'p256tag';
    final label = hybrid
        ? 'age-encryption.org/mlkem768p256tag'
        : 'age-encryption.org/p256tag';
    final scalar = hybrid ? null : _bigIntFromBytes(secretKey);
    final publicKey = hybrid
        ? mlKemP256KeyPair(secretKey).publicKey
        : p256Public(scalar!, compressed: true);
    final recipientForTag = hybrid ? publicKey.sublist(1184) : publicKey;
    for (final stanza in stanzas) {
      if (stanza.type != type) {
        continue;
      }
      if (stanza.args.length != 2 || stanza.body.length != 32) {
        throw AgeException('invalid $type stanza');
      }
      final tag = decodeBase64NoPad(stanza.args[0]);
      final encapsulated = decodeBase64NoPad(stanza.args[1]);
      final digest = await Sha256().hash(recipientForTag);
      final expectedTag = await hmacSha256(utf8.encode(label), [
        ...encapsulated,
        ...digest.bytes.take(4),
      ]);
      if (!constantTimeEquals(tag, expectedTag.sublist(0, 4))) {
        continue;
      }
      final shared = hybrid
          ? mlKemP256Decapsulate(secretKey, encapsulated)
          : await hpkeKemSharedSecret(
              hpkeDhKemP256,
              p256Shared(scalar!, encapsulated),
              encapsulated,
              p256Public(scalar, compressed: false),
            );
      final context = await hpkeContext(
        hybrid ? hpkeMlKem768P256 : hpkeDhKemP256,
        shared,
        label,
      );
      try {
        return await chacha20Poly1305Open(
          key: context.key,
          nonce: context.nonce,
          ciphertext: stanza.body,
        );
      } on AgeException {
        continue;
      } finally {
        shared.fillRange(0, shared.length, 0);
        context.key.fillRange(0, context.key.length, 0);
      }
    }
    return null;
  }
}
