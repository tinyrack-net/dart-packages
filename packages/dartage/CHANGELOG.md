# Changelog

## 0.2.0

- Replaced the mutable string-based API with `AgeRecipient`, `AgeIdentity`,
  immutable `AgeStanza`, and typed native key classes.
- Added scrypt, ML-KEM-768 + X25519, P-256 tag, and ML-KEM-768 + P-256 tag
  recipients.
- Added bounded streaming encryption, decryption, and ASCII armor while keeping
  buffer convenience methods on the same pipeline.
- Added configurable header and scrypt resource limits and reorganized public
  error codes.
- Pinned and enabled the complete C2SP CCTV age corpus and expanded
  `age-encryption` 0.3.0 interoperability coverage.
- Added 0.1.x migration and security documentation.

## 0.1.1

- Patch release to verify automated pub.dev publishing from GitHub Actions
  using OIDC. There are no API or runtime behavior changes.

## 0.1.0

- Initial extraction from the dotweave CLI, where this code has been in
  production use.
- age v1 encryption and decryption with X25519 recipients, ASCII armor,
  identity/recipient key handling, and STREAM payload framing.
- `scrypt` (passphrase) recipients are explicitly rejected rather than
  partially handled.
- Verified against a 30-vector fixture corpus and, in the tagged `interop`
  suite, against the reference `age-encryption` npm implementation.

Initial public release. The API is expected to change before 1.0.
