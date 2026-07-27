# Security notes

dartage delegates cryptographic primitives to `cryptography`, PointyCastle,
and `pqcrypto`. The package does not claim FIPS 140 or CMVP validation.

The implementation overwrites mutable file-key and derived-key buffers after
use on a best-effort basis. Dart garbage collection, compiler copies, immutable
`String` values, and platform cryptographic implementations prevent a
guarantee that every secret copy is erased. In particular, passphrases are
accepted as Dart `String` values and cannot be zeroized by the package.

Dart does not provide a general constant-time execution guarantee. Explicit
MAC and tag comparisons avoid data-dependent early exits, but callers should
not treat the managed runtime as a hardened side-channel boundary.

Scrypt encryption defaults to `logN=18`. Decryption rejects work factors above
20 by default before allocating KDF memory; applications can choose a lower
limit with `ScryptIdentity(maxWorkFactorLog2: ...)`.

Headers are limited to 16 MiB by default and parsed before payload processing.
Change `AgeDecrypter.maxHeaderBytes` only when the surrounding application has
an appropriate resource policy.

Do not reuse a passphrase chosen for low entropy. Prefer generated identities
or a high-entropy multi-word passphrase appropriate for offline password
guessing resistance.
