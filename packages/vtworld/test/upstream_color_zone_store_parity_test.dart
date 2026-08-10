import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('ColorZoneStore', () {
    late TerminalBufferNamespace buffers;
    late ColorZoneStore store;

    setUp(() {
      buffers = TerminalBufferNamespace(columns: 80, rows: 24, scrollback: 0);
      store = ColorZoneStore()
        ..setPadding(<TerminalOverviewRulerPosition, int>{
          for (final position in TerminalOverviewRulerPosition.values)
            position: 1,
        });
    });

    tearDown(() => buffers.dispose());

    test('should merge adjacent zones', () {
      store
        ..addDecoration(_decoration(buffers.active, 0))
        ..addDecoration(_decoration(buffers.active, 1));
      expect(store.zones, hasLength(1));
      expect(store.zones.single.startBufferLine, 0);
      expect(store.zones.single.endBufferLine, 1);
    });

    test('should not merge non-adjacent zones', () {
      store
        ..addDecoration(_decoration(buffers.active, 0))
        ..addDecoration(_decoration(buffers.active, 2));
      expect(store.zones, hasLength(2));
      expect(store.zones.first.startBufferLine, 0);
      expect(store.zones.last.startBufferLine, 2);
    });

    test('should reuse zone objects', () {
      store.addDecoration(_decoration(buffers.active, 0));
      final first = store.zones.single;
      store
        ..clear()
        ..addDecoration(_decoration(buffers.active, 1));
      expect(store.zones.single, same(first));
    });

    test('filters, extends and trims pooled zones', () {
      store.addDecoration(
        TerminalDecoration(marker: buffers.active.addMarker(0)),
      );
      expect(store.zones, isEmpty);
      store
        ..addDecoration(_decoration(buffers.active, 1))
        ..addDecoration(_decoration(buffers.active, 1))
        ..addDecoration(_decoration(buffers.active, 0));
      expect(store.zones.single.startBufferLine, 0);
      store.addDecoration(
        TerminalDecoration(
          marker: buffers.active.addMarker(5),
          overviewRulerColor: 'blue',
          overviewRulerPosition: TerminalOverviewRulerPosition.left,
        ),
      );
      expect(store.zones, hasLength(2));
      store
        ..clear()
        ..addDecoration(_decoration(buffers.active, 3));
      expect(store.zones, hasLength(1));
    });
  });
}

TerminalDecoration _decoration(TerminalBuffer buffer, int line) =>
    TerminalDecoration(
      marker: buffer.addMarker(line),
      overviewRulerColor: 'red',
    );
