import 'dart:io';

import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

final class _RecordingLogger implements ShipworldLogger {
  final messages = <String>[];

  @override
  void info(String message) => messages.add('info:$message');

  @override
  void progress(String message) => messages.add('progress:$message');
}

void main() {
  test('SilentShipworldLogger discards info and progress', () {
    const logger = SilentShipworldLogger();
    // Both sinks are no-ops; exercising them proves they do not throw.
    logger.info('ignored');
    logger.progress('ignored');
  });

  test('ShipworldContext.io captures the process environment', () {
    final context = ShipworldContext.io();

    expect(context.environment, isNotEmpty);
    expect(context.logger, isA<SilentShipworldLogger>());
  });

  test('ShipworldContext.io honors a provided logger', () {
    final logger = _RecordingLogger();
    final context = ShipworldContext.io(logger: logger);

    expect(identical(context.logger, logger), isTrue);
  });

  test('scoped getters fall back outside a context run', () {
    expect(currentShipworldEnvironment, Platform.environment);
    expect(currentShipworldLogger, isA<SilentShipworldLogger>());
  });

  test('scoped getters resolve context values inside run', () async {
    final logger = _RecordingLogger();
    final context = ShipworldContext(
      environment: const {'SHIPWORLD_SCOPE': 'active'},
      logger: logger,
    );

    await context.run(() async {
      expect(currentShipworldEnvironment['SHIPWORLD_SCOPE'], 'active');
      expect(identical(currentShipworldLogger, logger), isTrue);
    });
  });
}
