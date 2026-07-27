/// Native X25519 recipient and identity types.
library;

import 'dart:typed_data';

import 'exception.dart';
import 'keys.dart' as keys;
import 'primitives.dart';
import 'recipient.dart';
import 'stanza.dart';
import 'x25519_stanza.dart';

/// An X25519 age recipient.
final class X25519Recipient implements AgeRecipient {
  X25519Recipient._(this.encoded, this._publicKey);

  /// Parses an `age1...` recipient.
  factory X25519Recipient.parse(String encoded) {
    final normalized = encoded.trim();
    if (normalized != normalized.toLowerCase()) {
      throw const AgeException(
        'age recipients must use canonical lowercase bech32',
        code: AgeExceptionCode.invalidRecipient,
      );
    }
    return X25519Recipient._(normalized, keys.parseRecipient(normalized));
  }

  /// The encoded recipient string.
  final String encoded;
  final Uint8List _publicKey;

  @override
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey) async {
    return [await x25519Wrap(fileKey, _publicKey)];
  }

  @override
  String toString() => encoded;
}

/// An X25519 age identity.
final class X25519Identity implements AgeIdentity {
  X25519Identity._(this.encoded, this._scalar);

  /// Generates a fresh X25519 identity.
  factory X25519Identity.generate() {
    final encoded = keys.generateIdentity();
    return X25519Identity._(encoded, keys.parseIdentity(encoded));
  }

  /// Parses an `AGE-SECRET-KEY-1...` identity.
  factory X25519Identity.parse(String encoded) {
    final normalized = encoded.trim();
    if (normalized != normalized.toUpperCase()) {
      throw const AgeException(
        'age identities must use canonical uppercase bech32',
        code: AgeExceptionCode.invalidIdentity,
      );
    }
    return X25519Identity._(normalized, keys.parseIdentity(normalized));
  }

  /// The encoded identity string.
  final String encoded;
  final Uint8List _scalar;

  /// Derives the recipient corresponding to this identity.
  Future<X25519Recipient> recipient() async {
    return X25519Recipient.parse(await keys.identityToRecipient(encoded));
  }

  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    final publicKey = await x25519PublicKey(_scalar);
    for (final stanza in stanzas) {
      if (stanza.type != x25519StanzaType) {
        continue;
      }
      try {
        final fileKey = await x25519Unwrap(stanza, _scalar, publicKey);
        if (fileKey != null) {
          return fileKey;
        }
      } on AgeException {
        rethrow;
      }
    }
    return null;
  }

  @override
  String toString() => encoded;
}
