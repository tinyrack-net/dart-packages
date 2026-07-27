# dartage

`dartage` (pronounced “dart-age”) is a pure-Dart implementation of the
[age](https://age-encryption.org) v1 file format with X25519 recipients.

> **Status: 0.x.** The API is in production use but can still change before
> 1.0. Dotweave is its first consumer.

## Scope

Supported: X25519 recipients, the binary format, ASCII armor, `age1…` /
`AGE-SECRET-KEY-1…` key parsing and generation, and the STREAM payload
construction with its 64 KiB chunking.

**Not supported: scrypt (passphrase) recipients.** A file containing an
`scrypt` stanza is rejected with `AgeExceptionCode.passphraseUnsupported`
rather than silently mishandled.

## Usage

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartage/dartage.dart';

Future<void> main() async {
  final identity = generateIdentity();
  final recipient = await identityToRecipient(identity);

  final encrypter = AgeEncrypter()..addRecipient(recipient);
  final ciphertext = await encrypter.encrypt(
    Uint8List.fromList(utf8.encode('secret')),
  );

  final decrypter = AgeDecrypter()..addIdentity(identity);
  print(utf8.decode(await decrypter.decrypt(ciphertext)));
}
```

Use `armorEncode` / `armorDecode` for the PEM-style ASCII form.

## Correctness

The implementation is checked against a 30-vector fixture corpus covering
armor edge cases, header MAC tampering, truncated and non-canonical STREAM
payloads, low-order and non-canonical X25519 shares, grease stanzas, and
multi-recipient files. A separate interop suite encrypts and decrypts in both
directions against the reference `age-encryption` npm package, so wire
compatibility is verified rather than assumed:

```console
cd test/interop && pnpm install
dart test -t interop
```

The offline run is `dart test -x interop`.
