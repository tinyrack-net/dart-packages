/// Parsing dispatch for native age recipient and identity strings.
library;

import 'bech32.dart';
import 'exception.dart';
import 'hybrid.dart';
import 'recipient.dart';
import 'tag.dart';
import 'x25519.dart';

/// Parses one of the native recipient encodings supported by dartage.
AgeRecipient parseAgeRecipient(String encoded) {
  final String hrp;
  try {
    hrp = bech32Decode(encoded.trim()).hrp;
  } on AgeException catch (error) {
    throw AgeException(
      'invalid age recipient: ${error.message}',
      code: AgeExceptionCode.invalidRecipient,
    );
  }
  return switch (hrp) {
    'age' => X25519Recipient.parse(encoded),
    'age1pq' => MlKem768X25519Recipient.parse(encoded),
    'age1tag' => P256TagRecipient.parse(encoded),
    'age1tagpq' => MlKem768P256TagRecipient.parse(encoded),
    _ => throw const AgeException(
      'unsupported age recipient type',
      code: AgeExceptionCode.unsupportedType,
    ),
  };
}

/// Parses one of the native identity encodings supported by dartage.
AgeIdentity parseAgeIdentity(String encoded) {
  final String hrp;
  try {
    hrp = bech32Decode(encoded.trim()).hrp;
  } on AgeException catch (error) {
    throw AgeException(
      'invalid age identity: ${error.message}',
      code: AgeExceptionCode.invalidIdentity,
    );
  }
  return switch (hrp) {
    'age-secret-key-' => X25519Identity.parse(encoded),
    'age-secret-key-pq-' => MlKem768X25519Identity.parse(encoded),
    _ => throw const AgeException(
      'unsupported age identity type',
      code: AgeExceptionCode.unsupportedType,
    ),
  };
}
