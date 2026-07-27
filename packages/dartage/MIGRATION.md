# Migrating from dartage 0.1.x to 0.2.0

Version 0.2.0 replaces the mutable string-based builder API with typed,
immutable recipient and identity configuration.

| 0.1.x | 0.2.0 |
| --- | --- |
| `generateIdentity()` | `X25519Identity.generate()` |
| `identityToRecipient(identity)` | `await identity.recipient()` |
| `AgeEncrypter()..addRecipient(text)` | `AgeEncrypter(recipients: [parseAgeRecipient(text)])` |
| `AgeDecrypter()..addIdentity(text)` | `AgeDecrypter(identities: [parseAgeIdentity(text)])` |
| `armorEncode(bytes)` | `AgeArmor.encode(bytes)` |
| `armorDecode(text)` | `AgeArmor.decode(text)` |

Before:

```dart
final identity = generateIdentity();
final recipient = await identityToRecipient(identity);
final ciphertext =
    await (AgeEncrypter()..addRecipient(recipient)).encrypt(plaintext);
final recovered =
    await (AgeDecrypter()..addIdentity(identity)).decrypt(ciphertext);
```

After:

```dart
final identity = X25519Identity.generate();
final recipient = await identity.recipient();
final ciphertext = await AgeEncrypter(
  recipients: [recipient],
).encrypt(plaintext);
final recovered = await AgeDecrypter(
  identities: [identity],
).decrypt(ciphertext);
```

Passphrase files are now supported through `ScryptRecipient` and
`ScryptIdentity`; `AgeExceptionCode.passphraseUnsupported` no longer exists.
Authentication failures use `AgeExceptionCode.authenticationFailed`, and
invalid API setup uses `AgeExceptionCode.invalidConfiguration`.
