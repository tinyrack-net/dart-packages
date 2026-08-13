library;

// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';
import 'package:pointycastle/digests/shake.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pqcrypto/pqcrypto.dart';

import 'exception.dart';
import 'primitives.dart';

final _mlKem768 = PqcKem.kyber768;
final _p256 = ECDomainParameters('prime256v1');

Uint8List shake256(List<int> input, int length) {
  final digest = SHAKEDigest(256)
    ..update(Uint8List.fromList(input), 0, input.length);
  final output = Uint8List(length);
  digest.doFinalRange(output, 0, length);
  return output;
}

Uint8List sha3_256(List<int> input) {
  final digest = SHA3Digest(256);
  final data = Uint8List.fromList(input);
  digest.update(data, 0, data.length);
  final output = Uint8List(32);
  digest.doFinal(output, 0);
  return output;
}

BigInt _bytesToBigInt(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final output = Uint8List(length);
  var remaining = value;
  for (var i = length - 1; i >= 0; i--) {
    output[i] = (remaining & BigInt.from(0xff)).toInt();
    remaining >>= 8;
  }
  return output;
}

BigInt p256ScalarFromSeed(List<int> seed) {
  for (var offset = 0; offset + 32 <= seed.length; offset += 32) {
    final scalar = _bytesToBigInt(seed.sublist(offset, offset + 32));
    if (scalar > BigInt.zero && scalar < _p256.n) {
      return scalar;
    }
  }
  throw const AgeException('P-256 rejection sampling failed');
}

Uint8List p256Public(BigInt scalar, {required bool compressed}) {
  final point = _p256.G * scalar;
  if (point == null || point.isInfinity) {
    throw const AgeException('invalid P-256 scalar');
  }
  return point.getEncoded(compressed);
}

ECPoint p256Decode(List<int> encoded) {
  final validEncoding =
      (encoded.length == 33 && (encoded.first == 2 || encoded.first == 3)) ||
      (encoded.length == 65 && encoded.first == 4);
  if (!validEncoding) {
    throw const AgeException(
      'invalid P-256 point encoding',
      code: AgeExceptionCode.invalidRecipient,
    );
  }
  final ECPoint? point;
  try {
    point = _p256.curve.decodePoint(encoded);
  } on Object {
    throw const AgeException(
      'invalid P-256 recipient',
      code: AgeExceptionCode.invalidRecipient,
    );
  }
  if (point == null ||
      point.isInfinity ||
      (point * _p256.n)?.isInfinity != true) {
    throw const AgeException(
      'invalid P-256 recipient',
      code: AgeExceptionCode.invalidRecipient,
    );
  }
  return point;
}

Uint8List p256Shared(BigInt scalar, List<int> encodedPoint) {
  final point = p256Decode(encodedPoint) * scalar;
  if (point == null || point.isInfinity || point.x == null) {
    throw const AgeException('invalid P-256 shared secret');
  }
  return _bigIntToBytes(point.x!.toBigInteger()!, 32);
}

({Uint8List publicKey, Uint8List secretKey}) mlKemKeyPair(Uint8List seed) {
  final (publicKey, secretKey) = _mlKem768.generateKeyPair(seed);
  return (publicKey: publicKey, secretKey: secretKey);
}

({Uint8List ciphertext, Uint8List sharedSecret}) mlKemEncapsulate(
  Uint8List publicKey,
) {
  final (ciphertext, sharedSecret) = _mlKem768.encapsulate(publicKey);
  return (ciphertext: ciphertext, sharedSecret: sharedSecret);
}

Uint8List mlKemDecapsulate(Uint8List secretKey, Uint8List ciphertext) {
  return _mlKem768.decapsulate(secretKey, ciphertext);
}

Future<Uint8List> xWingPublic(Uint8List identity) async {
  final expanded = shake256(identity, 96);
  final ml = mlKemKeyPair(Uint8List.sublistView(expanded, 0, 64));
  final xPublic = await x25519PublicKey(
    Uint8List.sublistView(expanded, 64, 96),
  );
  return Uint8List.fromList([...ml.publicKey, ...xPublic]);
}

Future<({Uint8List ciphertext, Uint8List sharedSecret})> xWingEncapsulate(
  Uint8List recipient,
) async {
  if (recipient.length != 1216) {
    throw const AgeException('invalid hybrid recipient length');
  }
  final ml = mlKemEncapsulate(Uint8List.sublistView(recipient, 0, 1184));
  final xEphemeral = secureRandomBytes(32);
  final xCiphertext = await x25519PublicKey(xEphemeral);
  final xShared = await x25519SharedSecret(
    xEphemeral,
    Uint8List.sublistView(recipient, 1184),
  );
  final shared = sha3_256([
    ...ml.sharedSecret,
    ...xShared,
    ...xCiphertext,
    ...recipient.sublist(1184),
    ...const [0x5c, 0x2e, 0x2f, 0x2f, 0x5e, 0x5c],
  ]);
  return (
    ciphertext: Uint8List.fromList([...ml.ciphertext, ...xCiphertext]),
    sharedSecret: shared,
  );
}

Future<Uint8List> xWingDecapsulate(
  Uint8List identity,
  Uint8List ciphertext,
) async {
  if (ciphertext.length != 1120) {
    throw const AgeException('invalid hybrid encapsulated key length');
  }
  final expanded = shake256(identity, 96);
  final mlKeys = mlKemKeyPair(Uint8List.sublistView(expanded, 0, 64));
  final xScalar = Uint8List.sublistView(expanded, 64, 96);
  final xPublic = await x25519PublicKey(xScalar);
  final mlShared = mlKemDecapsulate(
    mlKeys.secretKey,
    Uint8List.sublistView(ciphertext, 0, 1088),
  );
  final xShared = await x25519SharedSecret(
    xScalar,
    Uint8List.sublistView(ciphertext, 1088),
  );
  return sha3_256([
    ...mlShared,
    ...xShared,
    ...ciphertext.sublist(1088),
    ...xPublic,
    ...const [0x5c, 0x2e, 0x2f, 0x2f, 0x5e, 0x5c],
  ]);
}

({Uint8List publicKey, Uint8List mlSecretKey, BigInt p256Scalar})
mlKemP256KeyPair(Uint8List seed) {
  final expanded = shake256(seed, 192);
  final ml = mlKemKeyPair(Uint8List.sublistView(expanded, 0, 64));
  final scalar = p256ScalarFromSeed(expanded.sublist(64));
  return (
    publicKey: Uint8List.fromList([
      ...ml.publicKey,
      ...p256Public(scalar, compressed: false),
    ]),
    mlSecretKey: ml.secretKey,
    p256Scalar: scalar,
  );
}

({Uint8List ciphertext, Uint8List sharedSecret}) mlKemP256Encapsulate(
  Uint8List recipient,
) {
  if (recipient.length != 1249) {
    throw const AgeException('invalid hybrid tag recipient length');
  }
  final ml = mlKemEncapsulate(Uint8List.sublistView(recipient, 0, 1184));
  final ephemeralSeed = secureRandomBytes(128);
  final scalar = p256ScalarFromSeed(ephemeralSeed);
  final pCiphertext = p256Public(scalar, compressed: false);
  final pShared = p256Shared(scalar, recipient.sublist(1184));
  return (
    ciphertext: Uint8List.fromList([...ml.ciphertext, ...pCiphertext]),
    sharedSecret: sha3_256([
      ...ml.sharedSecret,
      ...pShared,
      ...pCiphertext,
      ...recipient.sublist(1184),
      ...ascii.encode('MLKEM768-P256'),
    ]),
  );
}

Uint8List mlKemP256Decapsulate(Uint8List seed, Uint8List ciphertext) {
  if (seed.length != 32 || ciphertext.length != 1153) {
    throw const AgeException('invalid hybrid tag encapsulated key');
  }
  final keys = mlKemP256KeyPair(seed);
  final mlShared = mlKemDecapsulate(
    keys.mlSecretKey,
    Uint8List.sublistView(ciphertext, 0, 1088),
  );
  final pCiphertext = Uint8List.sublistView(ciphertext, 1088);
  final pShared = p256Shared(keys.p256Scalar, pCiphertext);
  return sha3_256([
    ...mlShared,
    ...pShared,
    ...pCiphertext,
    ...keys.publicKey.sublist(1184),
    ...ascii.encode('MLKEM768-P256'),
  ]);
}
