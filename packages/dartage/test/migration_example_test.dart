import 'package:test/test.dart';

import '../example/migration_0_2.dart' as migration;

void main() {
  test('the 0.1.x to 0.2.0 migration example compiles', () {
    expect(migration.main, isA<Future<void> Function()>());
  });
}
