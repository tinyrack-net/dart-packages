import 'package:test/test.dart';
import 'package:vtworld/src/core/unicode.dart';

void main() {
  group('unicode provider', () {
    late TerminalUnicodeHandling service;
    setUp(() => service = TerminalUnicodeHandling());

    test('default to V6', () {
      expect(service.activeVersion, '6');
      expect(service.versions, <String>['6']);
      expect(() => service.activeVersion = '6', returnsNormally);
      expect(service.getStringCellWidth('hello'), 5);
    });

    test('activate should throw for unknown version', () {
      expect(() => service.activeVersion = '55', throwsArgumentError);
    });

    test('should notify about version change', () {
      final notifications = <String>[];
      service.onChange.listen(notifications.add);
      const provider = _DummyProvider();
      service
        ..register(provider)
        ..activeVersion = provider.version;
      expect(notifications, <String>[provider.version]);
    });

    test('correctly changes provider impl', () {
      expect(service.getStringCellWidth('hello'), 5);
      const provider = _DummyProvider();
      service
        ..register(provider)
        ..activeVersion = provider.version;
      expect(service.getStringCellWidth('hello'), 10);
    });

    test('wcwidth V6 emoji test', () {
      expect(service.getStringCellWidth('🤣' * 10), 10);
    });
  });
}

final class _DummyProvider implements TerminalUnicodeProvider {
  const _DummyProvider();

  @override
  String get version => '123';

  @override
  int width(int codePoint) => 2;

  @override
  int charProperties(int codePoint, int precedingProperties) =>
      TerminalUnicodeHandling.createPropertyValue(0, width(codePoint));
}
