/// Native ML-KEM-768 plus X25519 recipient and identity types.
library;

import 'dart:typed_data';

import 'bech32.dart';
import 'exception.dart';
import 'hpke.dart';
import 'pq_primitives.dart';
import 'primitives.dart';
import 'recipient.dart';
import 'stanza.dart';

const String _recipientHrp = 'age1pq';
const String _identityHrp = 'age-secret-key-pq-';
const String _identityHrpUpper = 'AGE-SECRET-KEY-PQ-';
const String _stanzaType = 'mlkem768x25519';
const String _hpkeInfo = 'age-encryption.org/mlkem768x25519';

/// An ML-KEM-768 plus X25519 age recipient.
final class MlKem768X25519Recipient implements AgeRecipient {
  MlKem768X25519Recipient._(this.encoded, this._publicKey);

  /// Parses an `age1pq1...` recipient.
  factory MlKem768X25519Recipient.parse(String encoded) {
    final decoded = _decode(
      encoded,
      _recipientHrp,
      1216,
      AgeExceptionCode.invalidRecipient,
    );
    return MlKem768X25519Recipient._(encoded.trim(), decoded);
  }

  /// The canonical recipient string.
  final String encoded;
  final Uint8List _publicKey;

  @override
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey) async {
    final encapsulated = await xWingEncapsulate(_publicKey);
    final context = await hpkeContext(
      hpkeMlKem768X25519,
      encapsulated.sharedSecret,
      _hpkeInfo,
    );
    try {
      final body = await chacha20Poly1305Seal(
        key: context.key,
        nonce: context.nonce,
        plaintext: fileKey,
      );
      return [
        AgeStanza(_stanzaType, [
          encodeBase64NoPad(encapsulated.ciphertext),
        ], body),
      ];
    } finally {
      context.key.fillRange(0, context.key.length, 0);
      encapsulated.sharedSecret.fillRange(
        0,
        encapsulated.sharedSecret.length,
        0,
      );
    }
  }

  @override
  String toString() => encoded;
}

/// An ML-KEM-768 plus X25519 age identity.
final class MlKem768X25519Identity implements AgeIdentity {
  MlKem768X25519Identity._(this.encoded, this._seed);

  /// Generates a fresh identity.
  factory MlKem768X25519Identity.generate() {
    final seed = secureRandomBytes(32);
    return MlKem768X25519Identity._(
      bech32Encode(_identityHrpUpper, seed),
      seed,
    );
  }

  /// Parses an `AGE-SECRET-KEY-PQ-1...` identity.
  factory MlKem768X25519Identity.parse(String encoded) {
    final seed = _decode(
      encoded,
      _identityHrp,
      32,
      AgeExceptionCode.invalidIdentity,
    );
    return MlKem768X25519Identity._(encoded.trim(), seed);
  }

  /// The canonical identity string.
  final String encoded;
  final Uint8List _seed;

  /// Derives the public recipient for this identity.
  Future<MlKem768X25519Recipient> recipient() async {
    final publicKey = await xWingPublic(_seed);
    return MlKem768X25519Recipient.parse(
      bech32Encode(_recipientHrp, publicKey),
    );
  }

  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    for (final stanza in stanzas) {
      if (stanza.type != _stanzaType) {
        continue;
      }
      if (stanza.args.length != 1 || stanza.body.length != 32) {
        throw const AgeException('invalid MLKEM768-X25519 stanza');
      }
      final encapsulated = decodeBase64NoPad(stanza.args.single);
      if (encapsulated.length != 1120) {
        throw const AgeException('invalid MLKEM768-X25519 encapsulated key');
      }
      final sharedSecret = await xWingDecapsulate(_seed, encapsulated);
      final context = await hpkeContext(
        hpkeMlKem768X25519,
        sharedSecret,
        _hpkeInfo,
      );
      try {
        try {
          return await chacha20Poly1305Open(
            key: context.key,
            nonce: context.nonce,
            ciphertext: stanza.body,
          );
        } on AgeException catch (error) {
          if (error.code == AgeExceptionCode.authenticationFailed) {
            continue;
          }
          rethrow;
        }
      } finally {
        sharedSecret.fillRange(0, sharedSecret.length, 0);
        context.key.fillRange(0, context.key.length, 0);
      }
    }
    return null;
  }

  @override
  String toString() => encoded;
}

Uint8List _decode(
  String encoded,
  String expectedHrp,
  int expectedLength,
  AgeExceptionCode code,
) {
  final normalized = encoded.trim();
  final expectedCase = expectedHrp.startsWith('age-secret-key-')
      ? normalized.toUpperCase()
      : normalized.toLowerCase();
  if (normalized != expectedCase) {
    throw AgeException('hybrid key uses non-canonical case', code: code);
  }
  try {
    final decoded = bech32Decode(normalized);
    if (decoded.hrp != expectedHrp || decoded.data.length != expectedLength) {
      throw const AgeException('unexpected HRP or key length');
    }
    return decoded.data;
  } on AgeException catch (error) {
    throw AgeException('invalid hybrid key: ${error.message}', code: code);
  }
}
