library;
// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import 'exception.dart';
import 'primitives.dart';

final Uint8List _zeroNonce = Uint8List(12);

Future<Uint8List> encryptFileKey(Uint8List fileKey, Uint8List key) {
  return chacha20Poly1305Seal(key: key, nonce: _zeroNonce, plaintext: fileKey);
}

Future<Uint8List?> decryptFileKey(Uint8List body, Uint8List key) async {
  if (body.length != 32) {
    throw const AgeException('recipient stanza body must be 32 bytes');
  }
  try {
    return await chacha20Poly1305Open(
      key: key,
      nonce: _zeroNonce,
      ciphertext: body,
    );
  } on AgeException catch (error) {
    if (error.code == AgeExceptionCode.authenticationFailed) {
      return null;
    }
    rethrow;
  }
}
