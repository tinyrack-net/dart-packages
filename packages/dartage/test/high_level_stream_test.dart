import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartage/dartage.dart';
import 'package:test/test.dart';

void main() {
  test('arbitrary one-byte input chunks round-trip', () async {
    final identity = X25519Identity.generate();
    final plaintext = Uint8List.fromList(
      List<int>.generate(70000, (index) => index & 0xff),
    );
    final encrypted =
        await AgeEncrypter(recipients: [await identity.recipient()])
            .encryptStream(
              Stream<List<int>>.fromIterable(
                plaintext.map<List<int>>((byte) => [byte]),
              ),
            );
    final ciphertext = await _collect(encrypted);
    final decrypted = await AgeDecrypter(identities: [identity]).decryptStream(
      Stream<List<int>>.fromIterable(
        ciphertext.map<List<int>>((byte) => [byte]),
      ),
    );
    expect(await _collect(decrypted), plaintext);
  });

  test('decryption emits an authenticated chunk before source EOF', () async {
    final identity = X25519Identity.generate();
    final plaintext = Uint8List(2 * 65536);
    final ciphertext = await AgeEncrypter(
      recipients: [await identity.recipient()],
    ).encrypt(plaintext);
    final text = latin1.decode(ciphertext);
    final macStart = text.indexOf('\n--- ') + 1;
    final payloadOffset = text.indexOf('\n', macStart) + 1;
    final firstPartLength = payloadOffset + 16 + 65552 + 1;
    final source = StreamController<List<int>>();
    source.add(ciphertext.sublist(0, firstPartLength));
    final decrypted = await AgeDecrypter(identities: [identity])
        .decryptStream(source.stream);
    final firstOutput = Completer<Uint8List>();
    final allOutput = BytesBuilder(copy: false);
    final done = Completer<void>();
    decrypted.listen(
      (chunk) {
        allOutput.add(chunk);
        if (!firstOutput.isCompleted) {
          firstOutput.complete(chunk);
        }
      },
      onError: done.completeError,
      onDone: done.complete,
    );

    expect(await firstOutput.future, hasLength(65536));
    source.add(ciphertext.sublist(firstPartLength));
    await source.close();
    await done.future;
    expect(allOutput.toBytes(), plaintext);
  });

  test('source errors propagate through encryption', () async {
    final identity = X25519Identity.generate();
    final source = StreamController<List<int>>();
    final encrypted = await AgeEncrypter(
      recipients: [await identity.recipient()],
    ).encryptStream(source.stream);
    final collected = _collect(encrypted);
    final expectation = expectLater(collected, throwsA(isA<StateError>()));
    source
      ..add([1, 2, 3])
      ..addError(StateError('source failed'));
    await source.close();
    await expectation;
  });

  test('source errors propagate through decryption', () async {
    final identity = X25519Identity.generate();
    final ciphertext = await AgeEncrypter(
      recipients: [await identity.recipient()],
    ).encrypt(Uint8List(70000));
    final text = latin1.decode(ciphertext);
    final macStart = text.indexOf('\n--- ') + 1;
    final payloadOffset = text.indexOf('\n', macStart) + 1;
    final source = StreamController<List<int>>();
    source.add(ciphertext.sublist(0, payloadOffset + 16));
    final decrypted = await AgeDecrypter(identities: [identity])
        .decryptStream(source.stream);
    final expectation = expectLater(
      _collect(decrypted),
      throwsA(isA<StateError>()),
    );
    source.addError(StateError('ciphertext source failed'));
    await source.close();
    await expectation;
  });

  test('cancelling encryption cancels its plaintext source', () async {
    final identity = X25519Identity.generate();
    final sourceCancelled = Completer<void>();
    final source = StreamController<List<int>>(
      onCancel: sourceCancelled.complete,
    );
    final encrypted = await AgeEncrypter(
      recipients: [await identity.recipient()],
    ).encryptStream(source.stream);
    late StreamSubscription<Uint8List> subscription;
    final payloadObserved = Completer<void>();
    var outputs = 0;
    subscription = encrypted.listen((_) {
      outputs++;
      if (outputs == 3 && !payloadObserved.isCompleted) {
        payloadObserved.complete();
      }
    });
    source.add(Uint8List(70000));
    await payloadObserved.future;
    await subscription.cancel();
    await sourceCancelled.future;
  });

  test('pausing encrypted output applies backpressure to plaintext', () async {
    final identity = X25519Identity.generate();
    var sourceChunksRequested = 0;
    Stream<List<int>> source() async* {
      sourceChunksRequested++;
      yield Uint8List(70000);
      sourceChunksRequested++;
      yield Uint8List(1);
    }

    final encrypted = await AgeEncrypter(
      recipients: [await identity.recipient()],
    ).encryptStream(source());
    late StreamSubscription<Uint8List> subscription;
    final done = Completer<void>();
    final paused = Completer<void>();
    var outputs = 0;
    subscription = encrypted.listen((_) {
      outputs++;
      if (outputs == 3) {
        subscription.pause();
        paused.complete();
      }
    }, onDone: done.complete);
    await paused.future;
    await Future<void>.delayed(Duration.zero);
    expect(sourceChunksRequested, 1);
    subscription.resume();
    await done.future;
    expect(sourceChunksRequested, 2);
  });

  test('streaming armor matches one-shot armor', () async {
    final data = Uint8List.fromList(
      List<int>.generate(1000, (index) => index & 0xff),
    );
    final armoredBytes = await _collect(
      AgeArmor.encodeStream(
        Stream<List<int>>.fromIterable([
          data.sublist(0, 17),
          data.sublist(17, 319),
          data.sublist(319),
        ]),
      ),
    );
    expect(ascii.decode(armoredBytes), AgeArmor.encode(data));
    final decoded = await _collect(
      AgeArmor.decodeStream(
        Stream<List<int>>.fromIterable(
          armoredBytes.map<List<int>>((byte) => [byte]),
        ),
      ),
    );
    expect(decoded, data);
  });

  test('streaming armor maps non-ASCII input to a format error', () async {
    await expectLater(
      _collect(AgeArmor.decodeStream(Stream<List<int>>.value([0xff]))),
      throwsA(isA<AgeException>()),
    );
  });

  test('header limit is enforced before payload allocation', () async {
    final identity = X25519Identity.generate();
    final ciphertext = await AgeEncrypter(
      recipients: [await identity.recipient()],
    ).encrypt(Uint8List(0));
    await expectLater(
      AgeDecrypter(
        identities: [identity],
        maxHeaderBytes: 128,
      ).decrypt(ciphertext),
      throwsA(
        isA<AgeException>().having(
          (error) => error.code,
          'code',
          AgeExceptionCode.resourceLimitExceeded,
        ),
      ),
    );
  });

  test('custom recipient and identity contract is supported', () async {
    final plaintext = Uint8List.fromList([1, 3, 3, 7]);
    final ciphertext = await AgeEncrypter(recipients: [_TestRecipient()])
        .encrypt(plaintext);
    expect(
      await AgeDecrypter(identities: [_TestIdentity()]).decrypt(ciphertext),
      plaintext,
    );
    await expectLater(
      AgeDecrypter(identities: [_WrongLengthIdentity()]).decrypt(ciphertext),
      throwsA(
        isA<AgeException>().having(
          (error) => error.code,
          'code',
          AgeExceptionCode.invalidConfiguration,
        ),
      ),
    );
  });
}

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final output = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    output.add(chunk);
  }
  return output.toBytes();
}

final class _TestRecipient implements AgeRecipient {
  @override
  Future<List<AgeStanza>> wrapFileKey(Uint8List fileKey) async {
    return [AgeStanza('test', const [], fileKey)];
  }
}

final class _TestIdentity implements AgeIdentity {
  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    for (final stanza in stanzas) {
      if (stanza.type == 'test') {
        return Uint8List.fromList(stanza.body);
      }
    }
    return null;
  }
}

final class _WrongLengthIdentity implements AgeIdentity {
  @override
  Future<Uint8List?> unwrapFileKey(List<AgeStanza> stanzas) async {
    return Uint8List(15);
  }
}
