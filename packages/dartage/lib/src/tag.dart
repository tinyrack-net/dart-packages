/// P-256 tag and ML-KEM-768 plus P-256 tag recipients.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'bech32.dart';
import 'exception.dart';
import 'hpke.dart';
import 'pq_primitives.dart';
import 'primitives.dart';
import 'recipient.dart';
import 'stanza.dart';

const String _p256Hrp = 'age1tag';
const String _hybridHrp = 'age1tagpq';
const String _p256Type = 'p256tag';
const String _hybridType = 'mlkem768p256tag';
const String _p256Info = 'age-encryption.org/p256tag';
const String _hybridInfo = 'age-encryption.org/mlkem768p256tag';

/// A P-256 tag recipient.
final class P256TagRecipient implements AgeRecipient {
  P256TagRecipient._(this.encoded, this._compressedPublicKey);

  /// Parses an `age1tag1...` recipient.
  factory P256TagRecipient.parse(String encoded) {
    final key = _decodeRecipient(encoded, _p256Hrp, 33);
    p256Decode(key);
    return P256TagRecipient._(encoded.trim(), key);
  }

  /// The canonical recipient string.
  final String encoded;
  final Uint8List _compressedPublicKey;

  @override
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey) async {
    final recipientPoint = p256Decode(_compressedPublicKey);
    final recipient = recipientPoint.getEncoded(false);
    final scalar = p256ScalarFromSeed(secureRandomBytes(128));
    final encapsulated = p256Public(scalar, compressed: false);
    final rawShared = p256Shared(scalar, recipient);
    final shared = await hpkeKemSharedSecret(
      hpkeDhKemP256,
      rawShared,
      encapsulated,
      recipient,
    );
    return _wrapTagged(
      fileKey: fileKey,
      recipientForTag: _compressedPublicKey,
      encapsulated: encapsulated,
      sharedSecret: shared,
      kemId: hpkeDhKemP256,
      info: _p256Info,
      stanzaType: _p256Type,
      tagLabel: _p256Info,
    );
  }

  @override
  String toString() => encoded;
}

/// An ML-KEM-768 plus P-256 tag recipient.
final class MlKem768P256TagRecipient implements AgeRecipient {
  MlKem768P256TagRecipient._(this.encoded, this._publicKey);

  /// Parses an `age1tagpq1...` recipient.
  factory MlKem768P256TagRecipient.parse(String encoded) {
    final key = _decodeRecipient(encoded, _hybridHrp, 1249);
    p256Decode(key.sublist(1184));
    return MlKem768P256TagRecipient._(encoded.trim(), key);
  }

  /// The canonical recipient string.
  final String encoded;
  final Uint8List _publicKey;

  @override
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey) async {
    final encapsulated = mlKemP256Encapsulate(_publicKey);
    return _wrapTagged(
      fileKey: fileKey,
      recipientForTag: _publicKey.sublist(1184),
      encapsulated: encapsulated.ciphertext,
      sharedSecret: encapsulated.sharedSecret,
      kemId: hpkeMlKem768P256,
      info: _hybridInfo,
      stanzaType: _hybridType,
      tagLabel: _hybridInfo,
    );
  }

  @override
  String toString() => encoded;
}

Future<List<AgeStanza>> _wrapTagged({
  required Uint8List fileKey,
  required Uint8List recipientForTag,
  required Uint8List encapsulated,
  required Uint8List sharedSecret,
  required int kemId,
  required String info,
  required String stanzaType,
  required String tagLabel,
}) async {
  final digest = await Sha256().hash(recipientForTag);
  final tagMaterial = Uint8List.fromList([
    ...encapsulated,
    ...digest.bytes.take(4),
  ]);
  final fullTag = await hmacSha256(utf8.encode(tagLabel), tagMaterial);
  final context = await hpkeContext(kemId, sharedSecret, info);
  try {
    final body = await chacha20Poly1305Seal(
      key: context.key,
      nonce: context.nonce,
      plaintext: fileKey,
    );
    return [
      AgeStanza(stanzaType, [
        encodeBase64NoPad(fullTag.sublist(0, 4)),
        encodeBase64NoPad(encapsulated),
      ], body),
    ];
  } finally {
    sharedSecret.fillRange(0, sharedSecret.length, 0);
    context.key.fillRange(0, context.key.length, 0);
  }
}

Uint8List _decodeRecipient(
  String encoded,
  String expectedHrp,
  int expectedLength,
) {
  final normalized = encoded.trim();
  if (normalized != normalized.toLowerCase()) {
    throw const AgeException(
      'tag recipients must use canonical lowercase bech32',
      code: AgeExceptionCode.invalidRecipient,
    );
  }
  try {
    final decoded = bech32Decode(normalized);
    if (decoded.hrp != expectedHrp || decoded.data.length != expectedLength) {
      throw const AgeException('unexpected HRP or key length');
    }
    return decoded.data;
  } on AgeException catch (error) {
    throw AgeException(
      'invalid tag recipient: ${error.message}',
      code: AgeExceptionCode.invalidRecipient,
    );
  }
}
