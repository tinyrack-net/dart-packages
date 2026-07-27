library;
// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'primitives.dart';

const int hpkeMlKem768X25519 = 0x647a;
const int hpkeMlKem768P256 = 0x0050;
const int hpkeDhKemP256 = 0x0010;

Uint8List _concat(Iterable<List<int>> parts) {
  final length = parts.fold<int>(0, (sum, part) => sum + part.length);
  final output = Uint8List(length);
  var offset = 0;
  for (final part in parts) {
    output.setAll(offset, part);
    offset += part.length;
  }
  return output;
}

Future<Uint8List> _extract(List<int>? salt, List<int> ikm) {
  return hmacSha256(salt ?? Uint8List(32), ikm);
}

Future<Uint8List> _expand(Uint8List prk, List<int> info, int length) async {
  final block = await hmacSha256(prk, [...info, 1]);
  return Uint8List.fromList(block.sublist(0, length));
}

Uint8List _suiteId(int kemId) {
  return Uint8List.fromList([
    ...ascii.encode('HPKE'),
    kemId >> 8,
    kemId & 0xff,
    0,
    1,
    0,
    3,
  ]);
}

Future<Uint8List> _labeledExtract(
  Uint8List suiteId,
  List<int>? salt,
  String label,
  List<int> ikm,
) {
  return _extract(salt, [
    ...ascii.encode('HPKE-v1'),
    ...suiteId,
    ...ascii.encode(label),
    ...ikm,
  ]);
}

Future<Uint8List> _labeledExpand(
  Uint8List suiteId,
  Uint8List prk,
  String label,
  List<int> info,
  int length,
) {
  return _expand(prk, [
    length >> 8,
    length & 0xff,
    ...ascii.encode('HPKE-v1'),
    ...suiteId,
    ...ascii.encode(label),
    ...info,
  ], length);
}

Future<({Uint8List key, Uint8List nonce})> hpkeContext(
  int kemId,
  Uint8List sharedSecret,
  String info,
) async {
  final suiteId = _suiteId(kemId);
  final pskIdHash = await _labeledExtract(
    suiteId,
    null,
    'psk_id_hash',
    Uint8List(0),
  );
  final infoHash = await _labeledExtract(
    suiteId,
    null,
    'info_hash',
    utf8.encode(info),
  );
  final context = _concat([
    [0],
    pskIdHash,
    infoHash,
  ]);
  final secret = await _labeledExtract(
    suiteId,
    sharedSecret,
    'secret',
    Uint8List(0),
  );
  final key = await _labeledExpand(suiteId, secret, 'key', context, 32);
  final nonce = await _labeledExpand(
    suiteId,
    secret,
    'base_nonce',
    context,
    12,
  );
  return (key: key, nonce: nonce);
}

Future<Uint8List> hpkeKemSharedSecret(
  int kemId,
  Uint8List rawSharedSecret,
  Uint8List encapsulatedKey,
  Uint8List recipient,
) async {
  final suiteId = Uint8List.fromList([
    ...ascii.encode('KEM'),
    kemId >> 8,
    kemId & 0xff,
  ]);
  final eaePrk = await _labeledExtract(
    suiteId,
    null,
    'eae_prk',
    rawSharedSecret,
  );
  return _labeledExpand(suiteId, eaePrk, 'shared_secret', [
    ...encapsulatedKey,
    ...recipient,
  ], 32);
}
