/// Passphrase-based age recipient and identity types.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/scrypt.dart';

import 'exception.dart';
import 'file_key.dart';
import 'primitives.dart';
import 'recipient.dart';
import 'stanza.dart';

const _scryptType = 'scrypt';
const _scryptLabel = 'age-encryption.org/v1/scrypt';

Uint8List _deriveScryptKey(String passphrase, Uint8List salt, int logN) {
  final labeledSalt = Uint8List(utf8.encode(_scryptLabel).length + salt.length)
    ..setAll(0, utf8.encode(_scryptLabel))
    ..setAll(utf8.encode(_scryptLabel).length, salt);
  final derivator = Scrypt()
    ..init(ScryptParameters(1 << logN, 8, 1, 32, labeledSalt));
  final output = Uint8List(32);
  derivator.deriveKey(
    Uint8List.fromList(utf8.encode(passphrase)),
    0,
    output,
    0,
  );
  return output;
}

/// Encrypts file keys using an age passphrase stanza.
final class ScryptRecipient implements AgeRecipient {
  /// Creates a recipient with the age default work factor of 18.
  ScryptRecipient(this.passphrase, {this.workFactorLog2 = 18}) {
    if (workFactorLog2 < 1 || workFactorLog2 > 20) {
      throw const AgeException(
        'scrypt work factor must be between 1 and 20',
        code: AgeExceptionCode.invalidConfiguration,
      );
    }
  }

  /// The passphrase used to derive the wrapping key.
  final String passphrase;

  /// The base-2 logarithm of scrypt's work factor.
  final int workFactorLog2;

  @override
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey) async {
    final salt = secureRandomBytes(16);
    final key = _deriveScryptKey(passphrase, salt, workFactorLog2);
    try {
      return [
        AgeStanza(_scryptType, [
          encodeBase64NoPad(salt),
          '$workFactorLog2',
        ], await encryptFileKey(fileKey, key)),
      ];
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}

/// Decrypts age passphrase stanzas subject to a work-factor limit.
final class ScryptIdentity implements AgeIdentity {
  /// Creates a passphrase identity with a default maximum work factor of 20.
  ScryptIdentity(this.passphrase, {this.maxWorkFactorLog2 = 20}) {
    if (maxWorkFactorLog2 < 1 || maxWorkFactorLog2 > 30) {
      throw const AgeException(
        'scrypt maximum work factor must be between 1 and 30',
        code: AgeExceptionCode.invalidConfiguration,
      );
    }
  }

  /// The passphrase tried for matching scrypt stanzas.
  final String passphrase;

  /// The largest accepted base-2 work factor.
  final int maxWorkFactorLog2;

  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    final matching = stanzas.where((stanza) => stanza.type == _scryptType);
    if (matching.isEmpty) {
      return null;
    }
    if (stanzas.length != 1) {
      throw const AgeException(
        'an scrypt stanza must be the only stanza in the header',
      );
    }
    final stanza = matching.single;
    if (stanza.args.length != 2 ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(stanza.args[1])) {
      throw const AgeException('invalid scrypt stanza');
    }
    final salt = decodeBase64NoPad(stanza.args[0]);
    if (salt.length != 16 || stanza.body.length != 32) {
      throw const AgeException('invalid scrypt stanza');
    }
    final logN = int.tryParse(stanza.args[1]);
    if (logN == null || logN > maxWorkFactorLog2) {
      throw const AgeException(
        'scrypt work factor exceeds the configured limit',
        code: AgeExceptionCode.resourceLimitExceeded,
      );
    }
    final key = _deriveScryptKey(passphrase, salt, logN);
    try {
      return await decryptFileKey(stanza.body, key);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}
