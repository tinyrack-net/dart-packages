import 'package:test/test.dart';
import 'package:vtworld/src/core/marker.dart';
import 'package:vtworld/src/core/osc_link_service.dart';

void main() {
  group('OscLinkService', () {
    group('constructor', () {
      late TerminalMarkerFactory markerFactory;
      late List<TerminalMarker> markers;
      late OscLinkService service;

      setUp(() {
        markerFactory = TerminalMarkerFactory();
        markers = <TerminalMarker>[];
        service = OscLinkService(() => 0, (line) {
          final marker = markerFactory.create(line);
          markers.add(marker);
          return marker;
        });
      });

      test('link IDs are created and fetched consistently', () {
        const data = OscLinkData(id: 'foo', uri: 'bar');
        final linkId = service.registerLink(data);
        expect(linkId, greaterThan(0));
        expect(service.registerLink(data), linkId);
      });

      test(
        // Pinned upstream test identity.
        // ignore: lines_longer_than_80_chars
        'should dispose the link ID when the last marker is trimmed from the buffer',
        () {
          const data = OscLinkData(id: 'foo', uri: 'bar');
          final linkId = service.registerLink(data);
          expect(linkId, greaterThan(0));
          markers.single.move(-1);
          expect(service.registerLink(data), isNot(linkId));
        },
      );

      test('should fetch link data from link id', () {
        const data = OscLinkData(id: 'foo', uri: 'bar');
        final linkId = service.registerLink(data);
        expect(service.getLinkData(linkId), same(data));
      });
    });
  });
}
