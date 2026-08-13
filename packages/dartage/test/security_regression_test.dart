import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartage/dartage.dart';
import 'package:dartage/src/bech32.dart';
import 'package:dartage/src/hpke.dart';
import 'package:dartage/src/pq_primitives.dart';
import 'package:dartage/src/primitives.dart';
import 'package:dartage/src/stanza.dart';
import 'package:dartage/src/stream.dart';
import 'package:test/test.dart';

void main() {
  test('PQ recipients reject the wrong public-key length', () {
    final encoded = bech32Encode('age1pq', Uint8List(1215));
    expect(
      () => MlKem768X25519Recipient.parse(encoded),
      throwsA(
        isA<AgeException>().having(
          (error) => error.code,
          'code',
          AgeExceptionCode.invalidRecipient,
        ),
      ),
    );
  });

  test(
    'recipient and identity parsers reject non-canonical bech32 case',
    () async {
      final identity = X25519Identity.generate();
      final recipient = await identity.recipient();
      expect(
        () => X25519Recipient.parse(recipient.encoded.toUpperCase()),
        throwsA(isA<AgeException>()),
      );
      expect(
        () => X25519Identity.parse(identity.encoded.toLowerCase()),
        throwsA(isA<AgeException>()),
      );
    },
  );

  test('dispatch parsers distinguish malformed and unsupported encodings', () {
    expect(
      () => parseAgeRecipient('not-bech32'),
      throwsA(
        isA<AgeException>().having(
          (error) => error.code,
          'code',
          AgeExceptionCode.invalidRecipient,
        ),
      ),
    );
    expect(
      () => parseAgeIdentity(bech32Encode('other-secret-', Uint8List(32))),
      throwsA(
        isA<AgeException>().having(
          (error) => error.code,
          'code',
          AgeExceptionCode.unsupportedType,
        ),
      ),
    );
  });

  test('tag recipients reject invalid P-256 points', () {
    final encoded = bech32Encode('age1tag', Uint8List(33));
    expect(() => P256TagRecipient.parse(encoded), throwsA(isA<AgeException>()));
  });

  test('hybrid tag recipients reject invalid P-256 points', () {
    final encoded = bech32Encode('age1tagpq', Uint8List(1249));
    expect(
      () => MlKem768P256TagRecipient.parse(encoded),
      throwsA(isA<AgeException>()),
    );
  });

  for (final hybrid in [false, true]) {
    test(
      '${hybrid ? 'hybrid ' : ''}tag recipient round-trips through adapter',
      () async {
        final secret = hybrid
            ? Uint8List.fromList(List<int>.filled(32, 7))
            : Uint8List.fromList([...List<int>.filled(31, 0), 1]);
        final publicKey = hybrid
            ? mlKemP256KeyPair(secret).publicKey
            : p256Public(BigInt.one, compressed: true);
        final encoded = bech32Encode(
          hybrid ? 'age1tagpq' : 'age1tag',
          publicKey,
        );
        final recipient = parseAgeRecipient(encoded);
        expect(recipient.toString(), encoded);
        final plaintext = Uint8List.fromList([7, 6, 5, 4]);
        final ciphertext = await AgeEncrypter(recipients: [recipient])
            .encrypt(plaintext);
        expect(
          await AgeDecrypter(identities: [_TagIdentity(hybrid, secret)])
              .decrypt(ciphertext),
          plaintext,
        );
      },
    );
  }

  test('scrypt work factor is rejected before KDF allocation', () async {
    final stanza = AgeStanza('scrypt', [
      encodeBase64NoPad(Uint8List(16)),
      '21',
    ], Uint8List(32));
    await expectLater(
      ScryptIdentity('password').unwrapFileKey([stanza]),
      throwsA(
        isA<AgeException>().having(
          (error) => error.code,
          'code',
          AgeExceptionCode.resourceLimitExceeded,
        ),
      ),
    );
  });

  test('scrypt generates a fresh salt for every wrapped file key', () async {
    final recipient = ScryptRecipient('password', workFactorLog2: 1);
    final first = (await recipient.wrapFileKey(Uint8List(16))).single;
    final second = (await recipient.wrapFileKey(Uint8List(16))).single;
    expect(first.args.first, isNot(second.args.first));
  });

  test('AgeStanza defensively copies arguments and body', () {
    final arguments = ['one'];
    final body = Uint8List.fromList([1, 2, 3]);
    final stanza = AgeStanza('test', arguments, body);
    arguments[0] = 'changed';
    body[0] = 9;
    expect(stanza.args, ['one']);
    expect(stanza.body, [1, 2, 3]);
    expect(() => stanza.args.add('two'), throwsUnsupportedError);
    expect(() => stanza.body[0] = 4, throwsUnsupportedError);
  });

  test('STREAM counter encoding crosses the 257/258 chunk boundary', () {
    final nonce255 = streamChunkNonce(255, isFinal: false);
    final nonce256 = streamChunkNonce(256, isFinal: false);
    final nonce257 = streamChunkNonce(257, isFinal: true);
    expect(nonce255.sublist(8), [0, 0, 255, 0]);
    expect(nonce256.sublist(8), [0, 1, 0, 0]);
    expect(nonce257.sublist(8), [0, 1, 1, 1]);
    expect(nonce257[11], 1);
  });
}

final class _TagIdentity implements AgeIdentity {
  _TagIdentity(this.hybrid, this.secret);

  final bool hybrid;
  final Uint8List secret;

  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    final type = hybrid ? 'mlkem768p256tag' : 'p256tag';
    final label = hybrid
        ? 'age-encryption.org/mlkem768p256tag'
        : 'age-encryption.org/p256tag';
    final publicKey = hybrid
        ? mlKemP256KeyPair(secret).publicKey
        : p256Public(BigInt.one, compressed: true);
    final recipientForTag = hybrid ? publicKey.sublist(1184) : publicKey;
    for (final stanza in stanzas) {
      if (stanza.type != type) {
        continue;
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
          ? mlKemP256Decapsulate(secret, encapsulated)
          : await hpkeKemSharedSecret(
              hpkeDhKemP256,
              p256Shared(BigInt.one, encapsulated),
              encapsulated,
              p256Public(BigInt.one, compressed: false),
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
      } finally {
        shared.fillRange(0, shared.length, 0);
        context.key.fillRange(0, context.key.length, 0);
      }
    }
    return null;
  }
}
