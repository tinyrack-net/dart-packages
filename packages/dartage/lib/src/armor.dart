/// age ASCII armor: a strict subset of PEM using standard base64 with padding
/// and 64-character lines.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'exception.dart';
import 'stanza.dart';

const String _beginLine = '-----BEGIN AGE ENCRYPTED FILE-----';
const String _endLine = '-----END AGE ENCRYPTED FILE-----';

/// ASCII armor encoding and decoding, including bounded streaming variants.
abstract final class AgeArmor {
  /// Encodes a complete binary age file as ASCII armor.
  static String encode(Uint8List file) => armorEncode(file);

  /// Decodes a complete ASCII-armored age file.
  static Uint8List decode(String armored) => armorDecode(armored);

  /// Encodes a binary age stream as ASCII armor.
  static Stream<Uint8List> encodeStream(Stream<List<int>> file) async* {
    yield Uint8List.fromList(ascii.encode('$_beginLine\n'));
    var pending = Uint8List(0);
    await for (final chunk in file) {
      if (chunk.isEmpty) {
        continue;
      }
      pending = Uint8List.fromList([...pending, ...chunk]);
      while (pending.length >= 48) {
        final line = base64Encode(pending.sublist(0, 48));
        yield Uint8List.fromList(ascii.encode('$line\n'));
        pending = Uint8List.fromList(pending.sublist(48));
      }
    }
    if (pending.isNotEmpty) {
      yield Uint8List.fromList(ascii.encode('${base64Encode(pending)}\n'));
    }
    yield Uint8List.fromList(ascii.encode('$_endLine\n'));
  }

  /// Decodes an ASCII armor stream into binary age bytes.
  static Stream<Uint8List> decodeStream(Stream<List<int>> armored) async* {
    try {
      final lines = armored
          .transform(ascii.decoder)
          .transform(const LineSplitter());
      var state = 0;
      String? pending;
      await for (final line in lines) {
        if (state == 0) {
          if (line.trim().isEmpty) {
            continue;
          }
          if (line != _beginLine) {
            throw const AgeException('invalid armor begin line');
          }
          state = 1;
          continue;
        }
        if (state == 1) {
          if (line == _endLine) {
            if (pending != null) {
              if (pending.isEmpty ||
                  pending.length > 64 ||
                  pending.length % 4 != 0) {
                throw const AgeException('invalid armor line length');
              }
              yield _decodePaddedBase64(pending);
            }
            state = 2;
            continue;
          }
          if (pending != null) {
            if (pending.length != 64) {
              throw const AgeException('invalid armor line length');
            }
            yield _decodePaddedBase64(pending);
          }
          pending = line;
          continue;
        }
        if (line.trim().isNotEmpty) {
          throw const AgeException('non-whitespace data follows armor');
        }
      }
      if (state != 2) {
        throw const AgeException('invalid armor end line');
      }
    } on FormatException catch (error) {
      throw AgeException('invalid armor text: ${error.message}');
    }
  }
}

/// Encodes a binary age [file] into ASCII armor (with a final newline).
String armorEncode(Uint8List file) {
  final encoded = base64Encode(file);
  final buffer = StringBuffer()
    ..write(_beginLine)
    ..write('\n');
  for (var offset = 0; offset < encoded.length; offset += 64) {
    buffer
      ..write(encoded.substring(offset, min(offset + 64, encoded.length)))
      ..write('\n');
  }
  buffer
    ..write(_endLine)
    ..write('\n');
  return buffer.toString();
}

/// Decodes an ASCII armored age file. Extra whitespace before and after the
/// armor is ignored and newlines may be CRLF or LF; everything else is parsed
/// strictly (line lengths, label lines, canonical padded base64).
Uint8List armorDecode(String armored) {
  final lines = armored.trim().replaceAll('\r\n', '\n').split('\n');
  if (lines.isEmpty || lines.first != _beginLine) {
    throw const AgeException('invalid armor begin line');
  }
  if (lines.length < 2 || lines.last != _endLine) {
    throw const AgeException('invalid armor end line');
  }
  final body = lines.sublist(1, lines.length - 1);
  for (var i = 0; i < body.length; i++) {
    final length = body[i].length;
    final isLast = i == body.length - 1;
    final validLength = isLast
        ? length > 0 && length <= 64 && length % 4 == 0
        : length == 64;
    if (!validLength) {
      throw const AgeException('invalid armor line length');
    }
  }
  return _decodePaddedBase64(body.join());
}

Uint8List _decodePaddedBase64(String input) {
  if (input.length % 4 != 0) {
    throw const AgeException('invalid armor base64 length');
  }
  var padding = 0;
  var stripped = input;
  while (stripped.endsWith('=')) {
    stripped = stripped.substring(0, stripped.length - 1);
    padding++;
  }
  if (padding > 2 || stripped.contains('=')) {
    throw const AgeException('invalid armor base64 padding');
  }
  final expectedPadding = switch (stripped.length % 4) {
    0 => 0,
    2 => 2,
    3 => 1,
    _ => -1,
  };
  if (padding != expectedPadding) {
    throw const AgeException('invalid armor base64 padding');
  }
  return decodeBase64NoPad(stripped);
}
