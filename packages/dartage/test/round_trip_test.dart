import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartage/dartage.dart';
import 'package:dartage/src/header.dart';
import 'package:dartage/src/keys.dart' as keys;
import 'package:dartage/src/primitives.dart';
import 'package:dartage/src/stanza.dart';
import 'package:dartage/src/stream.dart' as payload;
import 'package:dartage/src/x25519_stanza.dart';
import 'package:test/test.dart';

void main() {
  group('native key types', () {
    test('X25519 generate, parse, and recipient are deterministic', () async {
      final identity = X25519Identity.generate();
      expect(identity.encoded, startsWith('AGE-SECRET-KEY-1'));
      expect(
        (await X25519Identity.parse(identity.encoded).recipient()).encoded,
        (await identity.recipient()).encoded,
      );
      expect(parseAgeIdentity(identity.encoded), isA<X25519Identity>());
      expect(
        parseAgeRecipient((await identity.recipient()).encoded),
        isA<X25519Recipient>(),
      );
    });

    test('hybrid generate, parse, and recipient are deterministic', () async {
      final identity = MlKem768X25519Identity.generate();
      final recipient = await identity.recipient();
      expect(identity.encoded, startsWith('AGE-SECRET-KEY-PQ-1'));
      expect(recipient.encoded, startsWith('age1pq1'));
      expect(
        (await MlKem768X25519Identity.parse(
          identity.encoded,
        ).recipient()).encoded,
        recipient.encoded,
      );
      expect(parseAgeIdentity(identity.encoded), isA<MlKem768X25519Identity>());
      expect(
        parseAgeRecipient(recipient.encoded),
        isA<MlKem768X25519Recipient>(),
      );
    });

    test('recipient and identity encodings are not interchangeable', () async {
      final identity = X25519Identity.generate();
      final recipient = await identity.recipient();
      expect(
        () => X25519Identity.parse(recipient.encoded),
        throwsA(
          isA<AgeException>().having(
            (error) => error.code,
            'code',
            AgeExceptionCode.invalidIdentity,
          ),
        ),
      );
      expect(
        () => X25519Recipient.parse(identity.encoded),
        throwsA(
          isA<AgeException>().having(
            (error) => error.code,
            'code',
            AgeExceptionCode.invalidRecipient,
          ),
        ),
      );
    });
  });

  group('encrypt/decrypt round-trip', () {
    final random = Random(20260724);
    for (final recipientCount in [1, 3]) {
      for (final size in [0, 1, 65535, 65536, 65537, 131072]) {
        test('$size bytes and $recipientCount recipients', () async {
          final identities = List<X25519Identity>.generate(
            recipientCount,
            (_) => X25519Identity.generate(),
          );
          final recipients = <X25519Recipient>[];
          for (final identity in identities) {
            recipients.add(await identity.recipient());
          }
          final plaintext = Uint8List.fromList(
            List<int>.generate(size, (_) => random.nextInt(256)),
          );
          final ciphertext = await AgeEncrypter(
            recipients: recipients,
          ).encrypt(plaintext);
          for (final identity in identities) {
            expect(
              await AgeDecrypter(identities: [identity]).decrypt(ciphertext),
              plaintext,
            );
          }
          expect(
            await AgeDecrypter(
              identities: [identities.last],
            ).decrypt(AgeArmor.decode(AgeArmor.encode(ciphertext))),
            plaintext,
          );
        });
      }
    }

    test('scrypt round-trip and wrong passphrase', () async {
      final plaintext = Uint8List.fromList(utf8.encode('correct horse'));
      final ciphertext = await AgeEncrypter(
        recipients: [ScryptRecipient('battery staple', workFactorLog2: 10)],
      ).encrypt(plaintext);
      expect(
        await AgeDecrypter(
          identities: [ScryptIdentity('battery staple')],
        ).decrypt(ciphertext),
        plaintext,
      );
      await expectLater(
        AgeDecrypter(identities: [ScryptIdentity('wrong')]).decrypt(ciphertext),
        throwsA(
          isA<AgeException>().having(
            (error) => error.code,
            'code',
            AgeExceptionCode.noIdentityMatched,
          ),
        ),
      );
    });

    test('hybrid recipient round-trip', () async {
      final identity = MlKem768X25519Identity.generate();
      final plaintext = Uint8List.fromList(utf8.encode('post quantum'));
      final ciphertext = await AgeEncrypter(
        recipients: [await identity.recipient()],
      ).encrypt(plaintext);
      expect(
        await AgeDecrypter(identities: [identity]).decrypt(ciphertext),
        plaintext,
      );
    });

    test('scrypt may not be mixed with another recipient', () async {
      final identity = X25519Identity.generate();
      await expectLater(
        AgeEncrypter(
          recipients: [
            ScryptRecipient('password', workFactorLog2: 10),
            await identity.recipient(),
          ],
        ).encrypt(Uint8List(1)),
        throwsA(
          isA<AgeException>().having(
            (error) => error.code,
            'code',
            AgeExceptionCode.invalidConfiguration,
          ),
        ),
      );
    });

    test('non-matching identity fails', () async {
      final target = X25519Identity.generate();
      final ciphertext = await AgeEncrypter(
        recipients: [await target.recipient()],
      ).encrypt(Uint8List(10));
      await expectLater(
        AgeDecrypter(
          identities: [X25519Identity.generate()],
        ).decrypt(ciphertext),
        throwsA(
          isA<AgeException>().having(
            (error) => error.code,
            'code',
            AgeExceptionCode.noIdentityMatched,
          ),
        ),
      );
    });

    test('empty configurations fail immediately', () {
      expect(
        () => AgeEncrypter(recipients: const []),
        throwsA(isA<AgeException>()),
      );
      expect(
        () => AgeDecrypter(identities: const []),
        throwsA(isA<AgeException>()),
      );
    });

    test('unknown stanza types are skipped', () async {
      final identity = X25519Identity.generate();
      final recipient = await identity.recipient();
      final plaintext = Uint8List.fromList(utf8.encode('hello grease'));
      final fileKey = secureRandomBytes(16);
      final stanzas = <Stanza>[
        Stanza('grease.example/v1', ['zzz'], secureRandomBytes(51)),
        await x25519Wrap(fileKey, keys.parseRecipient(recipient.encoded)),
        Stanza('another-unknown-type', [], secureRandomBytes(48)),
      ];
      final mac = await computeHeaderMac(
        fileKey,
        serializeHeaderWithoutMac(stanzas),
      );
      final header = serializeHeader(stanzas, mac);
      final encryptedPayload = await payload.encryptStream(fileKey, plaintext);
      final file = Uint8List.fromList([...header, ...encryptedPayload]);
      expect(
        await AgeDecrypter(identities: [identity]).decrypt(file),
        plaintext,
      );
    });
  });
}
