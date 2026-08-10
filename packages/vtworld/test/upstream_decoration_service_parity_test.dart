import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('DecorationService', () {
    late TerminalBufferNamespace buffers;
    late DecorationService service;

    setUp(() {
      buffers = TerminalBufferNamespace(
        columns: 80,
        rows: 24,
        scrollback: 1000,
      );
      service = DecorationService(buffers);
    });

    tearDown(() {
      service.dispose();
      buffers.dispose();
    });

    test('should set isDisposed to true after dispose', () {
      final decoration = _register(service, buffers.active, 1);
      expect(decoration.isDisposed, isFalse);
      decoration.dispose();
      expect(decoration.isDisposed, isTrue);
    });

    test('registration events and disposed marker rejection match xterm', () {
      final registered = <TerminalDecoration>[];
      final removed = <TerminalDecoration>[];
      service.onDecorationRegistered.listen(registered.add);
      service.onDecorationRemoved.listen(removed.add);
      final decoration = _register(service, buffers.active, 2);
      expect(service.decorations, contains(decoration));
      decoration.dispose();
      expect(registered, <TerminalDecoration>[decoration]);
      expect(removed, <TerminalDecoration>[decoration]);
      final marker = buffers.active.addMarker(3)..dispose();
      expect(
        service.registerDecoration(TerminalDecoration(marker: marker)),
        isNull,
      );
      service
        ..dispose()
        ..dispose();
    });

    group('forEachDecorationAtCell', () {
      test('should find decoration at its marker line', () {
        _register(service, buffers.active, 5, width: 10);
        final found = <TerminalDecoration>[];
        service.forEachDecorationAtCell(0, 5, null, found.add);
        expect(found, hasLength(1));
      });

      test('should find decoration with height > 1 on subsequent lines', () {
        _register(service, buffers.active, 5, width: 10, height: 3);
        for (final line in <int>[5, 6, 7]) {
          final found = <TerminalDecoration>[];
          service.forEachDecorationAtCell(0, line, null, found.add);
          expect(found, hasLength(1));
        }
        final outside = <TerminalDecoration>[];
        service.forEachDecorationAtCell(0, 8, null, outside.add);
        expect(outside, isEmpty);
      });

      test('should not find decoration outside its x range', () {
        _register(service, buffers.active, 5, x: 5, width: 3, height: 2);
        for (final cell in <(int, int, int)>[
          (4, 5, 0),
          (5, 5, 1),
          (7, 6, 1),
          (8, 5, 0),
        ]) {
          final found = <TerminalDecoration>[];
          service.forEachDecorationAtCell(cell.$1, cell.$2, null, found.add);
          expect(found, hasLength(cell.$3));
        }
      });

      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should find multi-line decoration when single-line decorations exist on other lines',
        () {
          for (var line = 0; line < buffers.active.length; line++) {
            _register(service, buffers.active, line, width: 5);
          }
          final multiLine = _register(
            service,
            buffers.active,
            10,
            width: 10,
            height: 3,
          );
          final found = <TerminalDecoration>[];
          service.forEachDecorationAtCell(0, 11, null, found.add);
          expect(found, contains(multiLine));
        },
      );
    });

    group('getDecorationsAtCell', () {
      test('getDecorationsAtCell finds height > 1 on subsequent lines', () {
        _register(service, buffers.active, 5, width: 10, height: 3);
        expect(service.getDecorationsAtCell(0, 5), hasLength(1));
        expect(service.getDecorationsAtCell(0, 6), hasLength(1));
        expect(service.getDecorationsAtCell(0, 7), hasLength(1));
        expect(service.getDecorationsAtCell(0, 8), isEmpty);
      });
    });

    group('DecorationLineCache', () {
      test('should return undefined for lines with no indexed decorations', () {
        final cache = DecorationLineCache();
        addTearDown(cache.dispose);
        expect(cache.getDecorationsOnLine(0), isNull);
      });
    });

    group('line index maintenance', () {
      test('should keep lookups correct after buffer trim', () {
        final localBuffers = TerminalBufferNamespace(
          columns: 80,
          rows: 3,
          scrollback: 1,
        );
        final localService = DecorationService(localBuffers);
        addTearDown(localService.dispose);
        addTearDown(localBuffers.dispose);
        final marker = localBuffers.active.addMarker(2);
        final decoration = _register(
          localService,
          localBuffers.active,
          marker.line,
          marker: marker,
          width: 10,
        );
        localBuffers.active
          ..scroll(TerminalCellAttributes())
          ..scroll(TerminalCellAttributes());
        expect(
          localService.getDecorationsAtCell(0, marker.line),
          contains(decoration),
        );
      });

      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should remove decoration from line index when marker is trimmed off buffer',
        () {
          final localBuffers = TerminalBufferNamespace(
            columns: 80,
            rows: 3,
            scrollback: 1,
          );
          final localService = DecorationService(localBuffers);
          addTearDown(localService.dispose);
          addTearDown(localBuffers.dispose);
          final marker = localBuffers.active.addMarker(0);
          final decoration = _register(
            localService,
            localBuffers.active,
            marker.line,
            marker: marker,
            width: 10,
          );
          localBuffers.active
            ..scroll(TerminalCellAttributes())
            ..scroll(TerminalCellAttributes());
          expect(marker.isDisposed, isTrue);
          expect(decoration.isDisposed, isTrue);
          expect(localService.getDecorationsAtCell(0, 0), isEmpty);
        },
      );

      test(
        'should keep multi-line decoration indexed after line insert',
        () async {
          final marker = buffers.active.addMarker(3);
          final decoration = _register(
            service,
            buffers.active,
            marker.line,
            marker: marker,
            width: 10,
            height: 3,
          );
          buffers.active.insertLines(5, 1, TerminalCellAttributes());
          await Future<void>.value();
          final found = <TerminalDecoration>[];
          for (var line = marker.line; line < marker.line + 3; line++) {
            service.forEachDecorationAtCell(0, line, null, found.add);
          }
          expect(found, contains(decoration));
          expect(service.getDecorationsAtCell(0, marker.line + 3), isEmpty);
        },
      );
    });
  });
}

TerminalDecoration _register(
  DecorationService service,
  TerminalBuffer buffer,
  int line, {
  TerminalMarker? marker,
  int x = 0,
  int width = 1,
  int height = 1,
}) {
  final decoration = TerminalDecoration(
    marker: marker ?? buffer.addMarker(line),
    x: x,
    width: width,
    height: height,
  );
  return service.registerDecoration(decoration)!;
}
