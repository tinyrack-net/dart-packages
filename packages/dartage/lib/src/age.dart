/// High-level age file encryption and decryption APIs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'exception.dart';
import 'header.dart';
import 'primitives.dart';
import 'recipient.dart';
import 'stanza.dart';
import 'stream.dart';

export 'armor.dart' show AgeArmor;
export 'exception.dart';
export 'hybrid.dart';
export 'parsing.dart';
export 'recipient.dart';
export 'scrypt.dart';
export 'stanza.dart' show AgeStanza;
export 'tag.dart';
export 'x25519.dart';

const int _defaultMaxHeaderBytes = 16 * 1024 * 1024;

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final output = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    output.add(chunk);
  }
  return output.toBytes();
}

/// Encrypts age files for one or more recipients.
final class AgeEncrypter {
  /// Creates an encrypter for the supplied recipients.
  AgeEncrypter({required Iterable<AgeRecipient> recipients})
    : _recipients = List<AgeRecipient>.unmodifiable(recipients) {
    if (_recipients.isEmpty) {
      throw const AgeException(
        'at least one recipient is required',
        code: AgeExceptionCode.invalidConfiguration,
      );
    }
  }

  final List<AgeRecipient> _recipients;

  /// Encrypts a complete byte buffer.
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final output = await encryptStream(Stream<List<int>>.value(plaintext));
    return _collect(output);
  }

  /// Encrypts a byte stream without buffering the complete payload.
  Future<Stream<Uint8List>> encryptStream(Stream<List<int>> plaintext) async {
    final fileKey = secureRandomBytes(16);
    final stanzas = <AgeStanza>[];
    try {
      for (final recipient in _recipients) {
        final wrapped = await recipient.wrapFileKey(
          Uint8List.fromList(fileKey),
        );
        stanzas.addAll(wrapped);
      }
      if (stanzas.isEmpty) {
        throw const AgeException(
          'recipients produced no stanzas',
          code: AgeExceptionCode.invalidConfiguration,
        );
      }
      if (stanzas.any((stanza) => stanza.type == 'scrypt') &&
          stanzas.length != 1) {
        throw const AgeException(
          'an scrypt stanza must be the only stanza in the header',
          code: AgeExceptionCode.invalidConfiguration,
        );
      }
      final macInput = serializeHeaderWithoutMac(stanzas);
      final mac = await computeHeaderMac(fileKey, macInput);
      final header = serializeHeader(stanzas, mac);
      final nonce = secureRandomBytes(streamNonceSize);
      final streamKey = await deriveStreamKey(fileKey, nonce);
      fileKey.fillRange(0, fileKey.length, 0);
      return _encryptPayload(plaintext, header, nonce, streamKey);
    } catch (_) {
      fileKey.fillRange(0, fileKey.length, 0);
      rethrow;
    }
  }

  Stream<Uint8List> _encryptPayload(
    Stream<List<int>> plaintext,
    Uint8List header,
    Uint8List nonce,
    Uint8List streamKey,
  ) async* {
    final pending = Uint8List(streamChunkSize);
    var pendingLength = 0;
    var counter = 0;
    final source = StreamIterator(plaintext);
    try {
      yield header;
      yield nonce;
      while (await source.moveNext()) {
        final sourceChunk = source.current;
        var offset = 0;
        while (offset < sourceChunk.length) {
          if (pendingLength == streamChunkSize) {
            yield await chacha20Poly1305Seal(
              key: streamKey,
              nonce: streamChunkNonce(counter, isFinal: false),
              plaintext: pending,
            );
            counter++;
            pendingLength = 0;
          }
          final take = min(
            streamChunkSize - pendingLength,
            sourceChunk.length - offset,
          );
          pending.setRange(
            pendingLength,
            pendingLength + take,
            sourceChunk,
            offset,
          );
          pendingLength += take;
          offset += take;
        }
      }
      yield await chacha20Poly1305Seal(
        key: streamKey,
        nonce: streamChunkNonce(counter, isFinal: true),
        plaintext: Uint8List.sublistView(pending, 0, pendingLength),
      );
    } finally {
      await source.cancel();
      streamKey.fillRange(0, streamKey.length, 0);
    }
  }
}

/// Decrypts age files with one or more identities.
final class AgeDecrypter {
  /// Creates a decrypter with a bounded header parser.
  AgeDecrypter({
    required Iterable<AgeIdentity> identities,
    this.maxHeaderBytes = _defaultMaxHeaderBytes,
  }) : _identities = List<AgeIdentity>.unmodifiable(identities) {
    if (_identities.isEmpty) {
      throw const AgeException(
        'at least one identity is required',
        code: AgeExceptionCode.invalidConfiguration,
      );
    }
    if (maxHeaderBytes < 128) {
      throw const AgeException(
        'maxHeaderBytes is too small',
        code: AgeExceptionCode.invalidConfiguration,
      );
    }
  }

  final List<AgeIdentity> _identities;

  /// The maximum number of header bytes accepted before payload processing.
  final int maxHeaderBytes;

  /// Decrypts a complete age file.
  Future<Uint8List> decrypt(Uint8List file) async {
    final output = await decryptStream(Stream<List<int>>.value(file));
    return _collect(output);
  }

  /// Decrypts an age file stream without buffering the complete payload.
  Future<Stream<Uint8List>> decryptStream(Stream<List<int>> file) async {
    final cursor = _ByteCursor(file);
    Uint8List? fileKey;
    try {
      final headerBytes = await cursor.readHeader(maxHeaderBytes);
      final header = parseHeader(headerBytes);
      for (final identity in _identities) {
        fileKey = await identity.unwrapFileKey(header.stanzas);
        if (fileKey != null) {
          break;
        }
      }
      if (fileKey == null) {
        await cursor.cancel();
        throw const AgeException(
          'no identity matched any recipient stanza',
          code: AgeExceptionCode.noIdentityMatched,
        );
      }
      if (fileKey.length != 16) {
        fileKey.fillRange(0, fileKey.length, 0);
        await cursor.cancel();
        throw const AgeException(
          'identity returned a file key with an invalid length',
          code: AgeExceptionCode.invalidConfiguration,
        );
      }
      await verifyHeaderMac(fileKey, header);
      final nonce = await cursor.readExactly(streamNonceSize);
      final streamKey = await deriveStreamKey(fileKey, nonce);
      fileKey.fillRange(0, fileKey.length, 0);
      fileKey = null;
      return _decryptPayload(cursor, streamKey);
    } catch (_) {
      fileKey?.fillRange(0, fileKey.length, 0);
      await cursor.cancel();
      rethrow;
    }
  }

  Stream<Uint8List> _decryptPayload(
    _ByteCursor cursor,
    Uint8List streamKey,
  ) async* {
    var pending = Uint8List(0);
    var counter = 0;
    try {
      while (true) {
        final next = await cursor.readUpTo(
          encryptedStreamChunkSize + 1 - pending.length,
        );
        if (next.isNotEmpty) {
          final combined = Uint8List(pending.length + next.length)
            ..setAll(0, pending)
            ..setAll(pending.length, next);
          pending = combined;
        }
        if (pending.length > encryptedStreamChunkSize) {
          final ciphertext = Uint8List.sublistView(
            pending,
            0,
            encryptedStreamChunkSize,
          );
          yield await chacha20Poly1305Open(
            key: streamKey,
            nonce: streamChunkNonce(counter, isFinal: false),
            ciphertext: ciphertext,
          );
          counter++;
          pending = Uint8List.fromList(
            pending.sublist(encryptedStreamChunkSize),
          );
          continue;
        }
        if (!cursor.isDone) {
          continue;
        }
        if (pending.length < streamTagSize) {
          throw const AgeException(
            'age payload chunk is truncated',
            code: AgeExceptionCode.authenticationFailed,
          );
        }
        final plaintext = await chacha20Poly1305Open(
          key: streamKey,
          nonce: streamChunkNonce(counter, isFinal: true),
          ciphertext: pending,
        );
        if (plaintext.isEmpty && counter != 0) {
          throw const AgeException(
            'age payload has an empty final chunk after non-empty chunks',
            code: AgeExceptionCode.authenticationFailed,
          );
        }
        yield plaintext;
        return;
      }
    } finally {
      streamKey.fillRange(0, streamKey.length, 0);
      await cursor.cancel();
    }
  }
}

final class _ByteCursor {
  _ByteCursor(Stream<List<int>> source) : _iterator = StreamIterator(source);

  final StreamIterator<List<int>> _iterator;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;
  bool _done = false;
  bool _cancelled = false;

  bool get isDone => _done && _offset == _buffer.length;

  Future<bool> _fill() async {
    if (_offset < _buffer.length) {
      return true;
    }
    while (await _iterator.moveNext()) {
      final current = _iterator.current;
      if (current.isNotEmpty) {
        _buffer = Uint8List.fromList(current);
        _offset = 0;
        return true;
      }
    }
    _done = true;
    return false;
  }

  Future<int?> readByte() async {
    if (!await _fill()) {
      return null;
    }
    return _buffer[_offset++];
  }

  Future<Uint8List> readExactly(int length) async {
    final result = BytesBuilder(copy: false);
    while (result.length < length) {
      final chunk = await readUpTo(length - result.length);
      if (chunk.isEmpty) {
        throw const AgeException(
          'truncated age file',
          code: AgeExceptionCode.authenticationFailed,
        );
      }
      result.add(chunk);
    }
    return result.toBytes();
  }

  Future<Uint8List> readUpTo(int length) async {
    if (length <= 0 || !await _fill()) {
      return Uint8List(0);
    }
    final take = min(length, _buffer.length - _offset);
    final result = Uint8List.fromList(_buffer.sublist(_offset, _offset + take));
    _offset += take;
    return result;
  }

  Future<Uint8List> readHeader(int maximumBytes) async {
    final bytes = BytesBuilder(copy: false);
    while (true) {
      final line = BytesBuilder(copy: false);
      while (true) {
        final byte = await readByte();
        if (byte == null) {
          throw const AgeException('truncated age header');
        }
        line.addByte(byte);
        if (bytes.length + line.length > maximumBytes) {
          throw const AgeException(
            'age header exceeds maxHeaderBytes',
            code: AgeExceptionCode.resourceLimitExceeded,
          );
        }
        if (byte == 0x0a) {
          break;
        }
      }
      final lineBytes = line.toBytes();
      bytes.add(lineBytes);
      final text = ascii.decode(
        lineBytes.sublist(0, lineBytes.length - 1),
        allowInvalid: true,
      );
      if (text.startsWith('--- ')) {
        return bytes.toBytes();
      }
    }
  }

  Future<void> cancel() async {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    await _iterator.cancel();
  }
}
