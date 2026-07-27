import 'dart:typed_data';

import 'package:dartage/dartage.dart';

Future<void> main() async {
  final identity = X25519Identity.generate();
  final ciphertext = await AgeEncrypter(
    recipients: [await identity.recipient()],
  ).encrypt(Uint8List.fromList([1, 2, 3]));
  await AgeDecrypter(identities: [identity]).decrypt(ciphertext);
}
