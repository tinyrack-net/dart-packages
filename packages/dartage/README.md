# dartage

`dartage` (pronounced “dart-age”) is a pure-Dart implementation of the
[age v1 file format](https://age-encryption.org). Version 0.2.0 exposes typed
recipient and identity extension points, complete-buffer convenience methods,
and bounded streaming encryption, decryption, and armor.

The implementation targets the C2SP age specification pinned at commit
`bd2d37c1b1adea2937f3f87d3b721f1dc119a10b`.

## Supported recipient types

- X25519 (`age1...` / `AGE-SECRET-KEY-1...`)
- scrypt passphrases
- ML-KEM-768 + X25519 (`age1pq...` / `AGE-SECRET-KEY-PQ-1...`)
- P-256 tag recipients (`age1tag...`)
- ML-KEM-768 + P-256 tag recipients (`age1tagpq...`)

The tag specifications do not define portable identity strings, so dartage
provides their recipient implementations only. Hardware, KMS, and application
integrations can supply an `AgeIdentity`.

## Usage

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartage/dartage.dart';

Future<void> main() async {
  final identity = X25519Identity.generate();
  final recipient = await identity.recipient();
  final plaintext = Uint8List.fromList(utf8.encode('secret'));

  final ciphertext = await AgeEncrypter(
    recipients: [recipient],
  ).encrypt(plaintext);

  final recovered = await AgeDecrypter(
    identities: [identity],
  ).decrypt(ciphertext);
  print(utf8.decode(recovered));
}
```

Passphrases use the same API:

```dart
final ciphertext = await AgeEncrypter(
  recipients: [ScryptRecipient('four random words')],
).encrypt(plaintext);

final plaintext = await AgeDecrypter(
  identities: [ScryptIdentity('four random words')],
).decrypt(ciphertext);
```

For streams, call `encryptStream` or `decryptStream` with a
`Stream<List<int>>`. They return `Future<Stream<Uint8List>>` because the
recipient header must be prepared or parsed before the output stream is
available. Payload processing retains at most one age chunk plus authentication
overhead. `AgeArmor.encodeStream` and `AgeArmor.decodeStream` provide the
corresponding ASCII armor pipeline.

Use `parseAgeRecipient` and `parseAgeIdentity` when the encoded key type is not
known in advance. Custom integrations implement `AgeRecipient` or
`AgeIdentity` and exchange immutable `AgeStanza` values.

## Scope

dartage is a cryptographic file-format library. It deliberately does not
discover SSH keys, launch age plugin processes, access WebAuthn/FIDO2 devices,
call KMS services, provide a CLI, or manage key files. Those responsibilities
belong in adapters and applications built on the public recipient/identity
interfaces.

Detached-header APIs and ciphertext size calculators are also outside 0.2.0.

## Verification

The offline suite runs the complete 143-vector C2SP CCTV age corpus pinned at
commit `1e3d2860d46e94e777e1b17c7a6f2436387e3ecc`.

The tagged interop suite verifies binary/armor operations in both directions
against `age-encryption` 0.3.0 for X25519, scrypt, and ML-KEM-768 + X25519.
P-256 tag variants use test-only identities with known private keys to verify
their stanza tags and HPKE contexts in both directions.

```console
cd test/interop
pnpm install --frozen-lockfile
cd ../..
dart test -t interop
```

The offline run is `dart test -x interop`.

See [MIGRATION.md](MIGRATION.md) for the 0.1.x API conversion and
[SECURITY.md](SECURITY.md) for runtime limitations and secret-handling notes.
