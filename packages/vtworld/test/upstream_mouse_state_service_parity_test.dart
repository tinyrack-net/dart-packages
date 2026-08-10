import 'package:test/test.dart';
import 'package:vtworld/src/core/mouse_state_service.dart';

void main() {
  group('MouseStateService', () {
    test('init', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      expect(service.activeEncoding, 'DEFAULT');
      expect(service.activeProtocol, 'NONE');
    });

    test('default protocols - NONE, X10, VT200, DRAG, ANY', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      expect(service.protocolNames, <String>[
        'NONE',
        'X10',
        'VT200',
        'DRAG',
        'ANY',
      ]);
    });

    test('default encodings - DEFAULT, SGR', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      expect(service.encodingNames, <String>['DEFAULT', 'SGR', 'SGR_PIXELS']);
    });

    test('protocol/encoding setter, reset', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      service
        ..activeEncoding = 'SGR'
        ..activeProtocol = 'ANY';
      expect(service.activeEncoding, 'SGR');
      expect(service.activeProtocol, 'ANY');
      service.reset();
      expect(service.activeEncoding, 'DEFAULT');
      expect(service.activeProtocol, 'NONE');
      expect(() => service.activeEncoding = 'xyz', throwsStateError);
      expect(() => service.activeProtocol = 'xyz', throwsStateError);
    });

    test('addEncoding', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      service
        ..addEncoding('XYZ', (_) => '')
        ..activeEncoding = 'XYZ';
      expect(service.activeEncoding, 'XYZ');
    });

    test('addProtocol', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      service
        ..addProtocol(
          'XYZ',
          CoreMouseProtocol(
            events: CoreMouseEventType.none,
            restrict: (_) => false,
          ),
        )
        ..activeProtocol = 'XYZ';
      expect(service.activeProtocol, 'XYZ');
    });

    test('onProtocolChange', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      final wantedEvents = <int>[];
      service.onProtocolChange.listen(wantedEvents.add);
      service.activeProtocol = 'NONE';
      expect(wantedEvents, <int>[CoreMouseEventType.none]);
      service.activeProtocol = 'ANY';
      expect(wantedEvents, <int>[
        CoreMouseEventType.none,
        CoreMouseEventType.down |
            CoreMouseEventType.up |
            CoreMouseEventType.wheel |
            CoreMouseEventType.drag |
            CoreMouseEventType.move,
      ]);
    });

    test('restrictMouseEvent/encodeMouseEvent', () {
      final service = MouseStateService();
      addTearDown(service.dispose);
      final event = CoreMouseEvent(
        column: 1,
        row: 1,
        x: 0,
        y: 0,
        button: CoreMouseButton.left,
        action: CoreMouseAction.down,
      );
      service
        ..activeProtocol = 'ANY'
        ..activeEncoding = 'DEFAULT';
      expect(service.restrictMouseEvent(event), isTrue);
      expect(service.encodeMouseEvent(event).codeUnits, <int>[
        0x1b,
        0x5b,
        0x4d,
        0x20,
        0x21,
        0x21,
      ]);
    });
  });
}
