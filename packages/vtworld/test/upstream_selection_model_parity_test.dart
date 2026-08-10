import 'package:test/test.dart';
import 'package:vtworld/src/core/selection_model.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm SelectionModel 00', () {
    final model = _model()
      ..selectionStart = _position(0, 0)
      ..selectionEnd = _position(10, 2);
    expect(model.finalSelectionStart, _position(0, 0));
    expect(model.finalSelectionEnd, _position(10, 2));
    model.clearSelection();
    expect(model.finalSelectionStart, isNull);
    expect(model.finalSelectionEnd, isNull);
  });

  test('xterm SelectionModel 01', () {
    final model = _model()
      ..selectionStart = _position(1, 0)
      ..selectionEnd = _position(0, 0);
    expect(model.areSelectionValuesReversed(), isTrue);
    model
      ..selectionStart = _position(10, 2)
      ..selectionEnd = _position(0, 0);
    expect(model.areSelectionValuesReversed(), isTrue);
  });

  test('xterm SelectionModel 02', () {
    final model = _model()
      ..selectionStart = _position(0, 0)
      ..selectionEnd = _position(1, 0);
    expect(model.areSelectionValuesReversed(), isFalse);
    model
      ..selectionStart = _position(0, 0)
      ..selectionEnd = _position(10, 2);
    expect(model.areSelectionValuesReversed(), isFalse);
  });

  test('xterm SelectionModel 03', () {
    final model = _model()
      ..selectionStart = _position(0, 0)
      ..selectionEnd = _position(10, 2)
      ..handleTrim(1);
    expect(model.finalSelectionStart, _position(0, 0));
    expect(model.finalSelectionEnd, _position(10, 1));
    model.handleTrim(1);
    expect(model.finalSelectionStart, _position(0, 0));
    expect(model.finalSelectionEnd, _position(10, 0));
  });

  test('xterm SelectionModel 04', () {
    final model = _model()
      ..selectionStart = _position(0, 0)
      ..selectionEnd = _position(10, 0)
      ..handleTrim(1);
    expect(model.finalSelectionStart, isNull);
    expect(model.finalSelectionEnd, isNull);
  });

  test('xterm SelectionModel 05', () {
    final model = _model()
      ..selectionStart = _position(50, 0)
      ..selectionEnd = _position(10, 2);
    expect(model.handleTrim(1), isTrue);
    expect(model.finalSelectionStart, _position(0, 0));
    expect(model.finalSelectionEnd, _position(10, 1));
  });

  test('xterm SelectionModel 06', () {
    final model = _model()..isSelectAllActive = true;
    expect(model.finalSelectionStart, _position(0, 0));
  });

  test('xterm SelectionModel 07', () {
    final model = _model()..selectionStart = _position(2, 2);
    expect(model.finalSelectionStart, _position(2, 2));
  });

  test('xterm SelectionModel 08', () {
    final model = _model()
      ..selectionStart = _position(2, 2)
      ..selectionEnd = _position(3, 2);
    expect(model.finalSelectionStart, _position(2, 2));
    model.selectionEnd = _position(1, 2);
    expect(model.finalSelectionStart, _position(1, 2));
  });

  test('xterm SelectionModel 09', () {
    final model = _model()..isSelectAllActive = true;
    expect(model.finalSelectionEnd, _position(80, 1));
  });

  test('xterm SelectionModel 10', () {
    final model = _model();
    expect(model.finalSelectionEnd, isNull);
    model.selectionEnd = _position(1, 2);
    expect(model.finalSelectionEnd, isNull);
  });

  test('xterm SelectionModel 11', () {
    final model = _model()
      ..selectionStart = _position(2, 2)
      ..selectionStartLength = 2;
    expect(model.finalSelectionEnd, _position(4, 2));
  });

  test('xterm SelectionModel 12', () {
    final model = _model()
      ..selectionStart = _position(2, 2)
      ..selectionStartLength = 2
      ..selectionEnd = _position(2, 1);
    expect(model.finalSelectionEnd, _position(4, 2));
  });

  test('xterm SelectionModel 13', () {
    final model = _model()
      ..selectionStart = _position(2, 2)
      ..selectionStartLength = 2
      ..selectionEnd = _position(3, 2);
    expect(model.finalSelectionEnd, _position(4, 2));
  });

  test('xterm SelectionModel 14', () {
    final model = _model()
      ..selectionStart = _position(78, 2)
      ..selectionStartLength = 4;
    expect(model.finalSelectionEnd, _position(2, 3));
  });

  test('xterm SelectionModel 15', () {
    final model = _model()
      ..selectionStart = _position(78, 2)
      ..selectionEnd = _position(79, 2)
      ..selectionStartLength = 4;
    expect(model.finalSelectionEnd, _position(2, 3));
  });

  test('xterm SelectionModel 16', () {
    final model = _model()
      ..selectionStart = _position(2, 2)
      ..selectionStartLength = 2
      ..selectionEnd = _position(5, 2);
    expect(model.finalSelectionEnd, _position(5, 2));
  });

  test('xterm SelectionModel 17', () {
    final model = _model()
      ..selectionStart = _position(0, 0)
      ..selectionStartLength = 80;
    expect(model.finalSelectionEnd, _position(80, 0));
    model
      ..selectionStart = _position(0, 0)
      ..selectionStartLength = 160;
    expect(model.finalSelectionEnd, _position(80, 1));
  });
}

SelectionModel _model() =>
    SelectionModel(columns: () => 80, rows: () => 2, bufferBaseY: () => 0);

TerminalBufferPosition _position(int x, int y) => TerminalBufferPosition(x, y);
