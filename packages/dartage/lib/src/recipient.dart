/// Public extension points for age recipient and identity implementations.
library;

import 'dart:typed_data';

import 'stanza.dart';

/// Wraps an age file key into one or more header stanzas.
abstract interface class AgeRecipient {
  /// Wraps a 16-byte file key into one or more header stanzas.
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey);
}

/// Attempts to unwrap an age file key from a header.
abstract interface class AgeIdentity {
  /// Returns `null` when none of [stanzas] target this identity.
  ///
  /// Implementations must throw when a stanza targets the identity but is
  /// malformed or fails for a reason other than a key mismatch.
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas);
}
