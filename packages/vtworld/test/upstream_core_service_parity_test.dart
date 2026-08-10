import 'package:test/test.dart';
import 'package:vtworld/src/core/core_service.dart';
import 'package:vtworld/src/core/options.dart';

void main() {
  group('CoreService', () {
    group('isCursorInitialized', () {
      test('should be false by default', () {
        final service = CoreService(options: TerminalOptions());
        expect(service.isCursorInitialized, isFalse);
      });

      test('should be true when showCursorImmediately is true', () {
        final service = CoreService(
          options: TerminalOptions(showCursorImmediately: true),
        );
        expect(service.isCursorInitialized, isTrue);
      });
    });

    group('reset', () {
      test('should not affect isCursorInitialized', () {
        final service = CoreService(options: TerminalOptions())
          ..isCursorInitialized = true
          ..reset();
        expect(service.isCursorInitialized, isTrue);
        service
          ..isCursorInitialized = false
          ..reset();
        expect(service.isCursorInitialized, isFalse);
      });
    });
  });
}
