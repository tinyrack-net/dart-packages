# Changelog

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
