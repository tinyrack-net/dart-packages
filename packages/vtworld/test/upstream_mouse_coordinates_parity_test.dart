import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('Mouse getCoords', () {
    const width = 10.0;
    const height = 20.0;
    const metrics = TerminalElementMetrics();

    (int, int)? coordinates(double x, double y, {bool selection = false}) =>
        getTerminalCellCoordinates(
          clientX: x,
          clientY: y,
          metrics: metrics,
          columns: 10,
          rows: 10,
          hasValidCharacterSize: true,
          cellWidth: width,
          cellHeight: height,
          isSelection: selection,
        );

    test('should return the cell that was clicked', () {
      expect(coordinates(width / 2, height / 2), (1, 1));
      expect(coordinates(width, height), (1, 1));
      expect(coordinates(width, height + 1), (1, 2));
      expect(coordinates(width + 1, height), (2, 1));
      expect(coordinates(width, height, selection: true), (2, 1));
      expect(
        getTerminalCellCoordinates(
          clientX: 0,
          clientY: 0,
          metrics: metrics,
          columns: 10,
          rows: 10,
          hasValidCharacterSize: false,
          cellWidth: width,
          cellHeight: height,
        ),
        isNull,
      );
    });

    test(
      'should ensure the coordinates are returned within the terminal bounds',
      () {
        expect(coordinates(-1, -1), (1, 1));
        expect(coordinates(width * 20, height * 20), (10, 10));
        expect(
          getCoordsRelativeToElement(
            15,
            25,
            const TerminalElementMetrics(
              left: 2,
              top: 3,
              paddingLeft: 4,
              paddingTop: 5,
            ),
          ),
          (9, 17),
        );
      },
    );
  });
}
