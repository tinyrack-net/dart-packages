/// Error codes attached to [AgeException] so callers can map failures
/// without parsing messages.
enum AgeExceptionCode {
  /// Malformed input (header, stanza, armor, bech32, base64, ...).
  invalidFormat,

  /// An `age1...` recipient string could not be parsed.
  invalidRecipient,

  /// An `AGE-SECRET-KEY-1...` identity string could not be parsed.
  invalidIdentity,

  /// None of the provided identities matched the file's recipient stanzas.
  noIdentityMatched,

  /// Cryptographic verification failed (MAC mismatch, AEAD open failure).
  authenticationFailed,

  /// The operation was invoked with invalid arguments or state.
  invalidConfiguration,

  /// The input requested more memory or work than the configured safety limit.
  resourceLimitExceeded,

  /// The encoded recipient or identity type is not implemented.
  unsupportedType,
}

/// Exception thrown by the age encryption module.
class AgeException implements Exception {
  /// Creates an [AgeException] with a human readable [message].
  const AgeException(
    this.message, {
    this.code = AgeExceptionCode.invalidFormat,
  });

  /// Human readable description of the failure.
  final String message;

  /// Machine readable error category.
  final AgeExceptionCode code;

  @override
  String toString() => 'AgeException(${code.name}): $message';
}
