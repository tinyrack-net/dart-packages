import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('TextBlinkStateManager', () {
    test('starts interval only when needed', () {
      final fixture = _fixture(100);
      addTearDown(fixture.dispose);
      expect(fixture.host.callbacks, isEmpty);
      fixture.manager.setNeedsBlinkInViewport(value: true);
      expect(fixture.host.callbacks, hasLength(1));
      expect(fixture.manager.isEnabled, isTrue);
    });

    test(
      'stops interval and restores blink visibility when no longer needed',
      () {
        final fixture = _fixture(100);
        addTearDown(fixture.dispose);
        fixture.manager.setNeedsBlinkInViewport(value: true);
        fixture.host.callbacks.values.single();
        final rendersAfterTick = fixture.renderCount;
        expect(fixture.manager.isBlinkOn, isFalse);
        fixture.manager.setNeedsBlinkInViewport(value: false);
        expect(fixture.host.callbacks, isEmpty);
        expect(fixture.manager.isBlinkOn, isTrue);
        expect(fixture.renderCount, rendersAfterTick + 1);
      },
    );

    test('pauses while viewport is hidden and resumes when visible', () {
      final fixture = _fixture(100);
      addTearDown(fixture.dispose);
      fixture.manager
        ..setNeedsBlinkInViewport(value: true)
        ..setViewportVisible(value: false);
      expect(fixture.host.callbacks, isEmpty);
      fixture.manager.setViewportVisible(value: true);
      expect(fixture.host.callbacks, hasLength(1));
    });

    test('does not start interval when duration is zero', () {
      final fixture = _fixture(0);
      addTearDown(fixture.dispose);
      fixture.manager.setNeedsBlinkInViewport(value: true);
      expect(fixture.host.callbacks, isEmpty);
      expect(fixture.manager.isEnabled, isFalse);
    });

    test('live duration and idempotent state changes preserve one timer', () {
      final fixture = _fixture(100);
      addTearDown(fixture.dispose);
      fixture.manager
        ..setNeedsBlinkInViewport(value: true)
        ..setNeedsBlinkInViewport(value: true)
        ..setViewportVisible(value: true)
        ..setIntervalDuration(100);
      expect(fixture.host.callbacks, hasLength(1));
      fixture.options.blinkIntervalDuration = 200;
      expect(fixture.host.callbacks, hasLength(1));
      fixture.manager
        ..dispose()
        ..dispose();
      expect(fixture.host.callbacks, isEmpty);
    });
  });
}

_BlinkFixture _fixture(int duration) {
  final host = _FakeTimerHost();
  final options = TerminalOptions(blinkIntervalDuration: duration);
  late _BlinkFixture fixture;
  final manager = TextBlinkStateManager(
    renderCallback: () => fixture.renderCount++,
    timerHost: host,
    options: options,
  );
  return fixture = _BlinkFixture(manager, host, options);
}

final class _BlinkFixture {
  _BlinkFixture(this.manager, this.host, this.options);

  final TextBlinkStateManager manager;
  final _FakeTimerHost host;
  final TerminalOptions options;
  int renderCount = 0;

  void dispose() => manager.dispose();
}

final class _FakeTimerHost implements TextBlinkTimerHost {
  final Map<int, void Function()> callbacks = <int, void Function()>{};
  int nextId = 1;

  @override
  int setInterval(void Function() callback, Duration duration) {
    final id = nextId++;
    callbacks[id] = callback;
    return id;
  }

  @override
  void clearInterval(int id) => callbacks.remove(id);
}
