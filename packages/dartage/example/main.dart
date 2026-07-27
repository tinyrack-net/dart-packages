// Generate a keypair, encrypt to it, and decrypt back.
//
// Run it with:
//   dart run example/main.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartage/dartage.dart';

Future<void> main() async {
  final identity = X25519Identity.generate();
  final recipient = await identity.recipient();

  print('recipient: $recipient');

  final ciphertext = await AgeEncrypter(
    recipients: [recipient],
  ).encrypt(Uint8List.fromList(utf8.encode('secret')));

  // `AgeArmor.encode` produces the PEM-style text form for storing in a file.
  print(AgeArmor.encode(ciphertext).split('\n').first);

  final plaintext = await AgeDecrypter(
    identities: [identity],
  ).decrypt(ciphertext);

  print('decrypted: ${utf8.decode(plaintext)}');
}
