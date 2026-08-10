import 'package:test/test.dart';
import 'package:vtworld/src/core/width_cache.dart';

void main() {
  late _MockCanvasFactory factory;
  late WidthCache cache;

  setUp(() {
    factory = _MockCanvasFactory();
    cache = WidthCache(factory.create)
      ..setFont('monospace', 15, 'normal', 'bold');
  });

  tearDown(() => cache.dispose());

  group('WidthCache', () {
    group('cache invalidation', () {
      test('can cache values', () {
        expect(cache.get('a', false, false), 5);
        expect(cache.get('a', true, false), 5);
        expect(cache.flatCache[97], 5);
        expect(cache.sparseCache, containsPair('aB', 5));
      });

      test('clear resets cache entries', () {
        cache
          ..get('a', false, false)
          ..get('a', true, false)
          ..clear();
        expect(cache.flatCache[97], WidthCache.flatUnset);
        expect(cache.sparseCache, isEmpty);
      });

      test('setFont with changed font name', () {
        cache
          ..get('a', false, false)
          ..setFont('Arial', 15, 'normal', 'bold');
        expect(cache.flatCache[97], WidthCache.flatUnset);
      });

      test('setFont with changed font size', () {
        cache
          ..get('a', false, false)
          ..setFont('monospace', 14, 'normal', 'bold');
        expect(cache.flatCache[97], WidthCache.flatUnset);
      });

      test('setFont with changed weight', () {
        cache
          ..get('a', false, false)
          ..setFont('monospace', 15, '100', 'bold');
        expect(cache.flatCache[97], WidthCache.flatUnset);
      });

      test('setFont with changed weightBold', () {
        cache
          ..get('a', false, false)
          ..setFont('monospace', 15, 'normal', '900');
        expect(cache.flatCache[97], WidthCache.flatUnset);
      });

      test('setFont with unchanged settings does not cache entries', () {
        cache
          ..get('a', false, false)
          ..get('a', true, false)
          ..setFont('monospace', 15, 'normal', 'bold');
        expect(cache.flatCache[97], 5);
        expect(cache.sparseCache, containsPair('aB', 5));
      });
    });

    group('get', () {
      test('store regular < WidthCacheSettings.FLAT_SIZE in flat', () {
        for (var code = 0; code < WidthCache.flatSize + 10; code++) {
          final text = String.fromCharCode(code);
          expect(cache.get(text, false, false), 5);
          if (code < WidthCache.flatSize) {
            expect(cache.flatCache[code], 5);
            expect(cache.sparseCache, isNot(contains(text)));
          } else {
            expect(cache.sparseCache, containsPair(text, 5));
          }
        }
      });

      test('stores bold & italic in holey', () {
        expect(cache.get('b', true, false), 5);
        expect(cache.get('i', false, true), 5);
        expect(cache.get('x', true, true), 5);
        expect(cache.sparseCache, containsPair('bB', 5));
        expect(cache.sparseCache, containsPair('iI', 5));
        expect(cache.sparseCache, containsPair('xBI', 5));
      });

      test('can store any string', () {
        expect(cache.get('foo', false, false), 5);
        expect(cache.get('bar&baz', true, true), 5);
        expect(cache.sparseCache, containsPair('foo', 5));
        expect(cache.sparseCache, containsPair('bar&bazBI', 5));
      });
    });
  });
}

final class _MockCanvasFactory {
  final canvases = <_MockCanvas>[];

  WidthCacheCanvas create() {
    final canvas = _MockCanvas();
    canvases.add(canvas);
    return canvas;
  }
}

final class _MockCanvas implements WidthCacheCanvas {
  @override
  double measure(String text) => 5;

  @override
  void setFont(
    String family,
    double size,
    Object weight, {
    required bool italic,
  }) {}
}
