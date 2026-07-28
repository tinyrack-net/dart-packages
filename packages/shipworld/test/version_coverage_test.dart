import 'package:shipworld/release.dart';
import 'package:test/test.dart';

void main() {
  group('Version value semantics', () {
    test('hashCode is stable and equal for equal versions', () {
      const a = Version(major: 1, minor: 2, patch: 3);
      const b = Version(major: 1, minor: 2, patch: 3);

      expect(a.hashCode, b.hashCode);
      final deduplicated = <Version>{}
        ..add(a)
        ..add(b);
      expect(deduplicated, hasLength(1));
    });

    test('hashCode differs for different versions', () {
      const a = Version(major: 1, minor: 2, patch: 3);
      const b = Version(major: 1, minor: 2, patch: 4);

      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('toString renders the formatted version', () {
      const version = Version(major: 4, minor: 5, patch: 6);

      expect(version.toString(), '4.5.6');
      expect('$version', '4.5.6');
    });
  });
}
