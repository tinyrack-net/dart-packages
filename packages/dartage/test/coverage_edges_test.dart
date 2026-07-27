import 'dart:typed_data';

import 'package:dartage/src/armor.dart';
import 'package:dartage/src/exception.dart';
import 'package:dartage/src/header.dart';
import 'package:test/test.dart';

void main() {
  test('AgeException exposes a stable diagnostic string', () {
    const exception = AgeException(
      'broken input',
      code: AgeExceptionCode.decryptionFailed,
    );

    expect(
      exception.toString(),
      'AgeException(decryptionFailed): broken input',
    );
  });

  test('armor rejects an impossible base64 length', () {
    const armored =
        '-----BEGIN AGE ENCRYPTED FILE-----\n'
        'A\n'
        '-----END AGE ENCRYPTED FILE-----\n';

    expect(
      () => armorDecode(armored),
      throwsA(
        isA<AgeException>().having(
          (error) => error.message,
          'message',
          contains('line length'),
        ),
      ),
    );
  });

  test('header reader reports input without any newline as truncated', () {
    expect(
      () => parseHeader(Uint8List.fromList('age-encryption.org/v1'.codeUnits)),
      throwsA(
        isA<AgeException>().having(
          (error) => error.message,
          'message',
          contains('missing newline'),
        ),
      ),
    );
  });
}
