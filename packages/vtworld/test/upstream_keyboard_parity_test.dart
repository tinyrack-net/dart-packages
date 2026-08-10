import 'dart:convert';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

import 'support/fixture_paths.dart';

void main() {
  final cases = _loadCases();
  test('xterm Keyboard 00', () => _runCase(0, cases));
  test('xterm Keyboard 01', () => _runCase(1, cases));
  test('xterm Keyboard 02', () => _runCase(2, cases));
  test('xterm Keyboard 03', () => _runCase(3, cases));
  test('xterm Keyboard 04', () => _runCase(4, cases));
  test('xterm Keyboard 05', () => _runCase(5, cases));
  test('xterm Keyboard 06', () => _runCase(6, cases));
  test('xterm Keyboard 07', () => _runCase(7, cases));
  test('xterm Keyboard 08', () => _runCase(8, cases));
  test('xterm Keyboard 09', () => _runCase(9, cases));
  test('xterm Keyboard 10', () => _runCase(10, cases));
  test('xterm Keyboard 11', () => _runCase(11, cases));
  test('xterm Keyboard 12', () => _runCase(12, cases));
  test('xterm Keyboard 13', () => _runCase(13, cases));
  test('xterm Keyboard 14', () => _runCase(14, cases));
  test('xterm Keyboard 15', () => _runCase(15, cases));
  test('xterm Keyboard 16', () => _runCase(16, cases));
  test('xterm Keyboard 17', () => _runCase(17, cases));
  test('xterm Keyboard 18', () => _runCase(18, cases));
  test('xterm Keyboard 19', () => _runCase(19, cases));
  test('xterm Keyboard 20', () => _runCase(20, cases));
  test('xterm Keyboard 21', () => _runCase(21, cases));
  test('xterm Keyboard 22', () => _runCase(22, cases));
  test('xterm Keyboard 23', () => _runCase(23, cases));
  test('xterm Keyboard 24', () => _runCase(24, cases));
  test('xterm Keyboard 25', () => _runCase(25, cases));
  test('xterm Keyboard 26', () => _runCase(26, cases));
  test('xterm Keyboard 27', () => _runCase(27, cases));
  test('xterm Keyboard 28', () => _runCase(28, cases));
  test('xterm Keyboard 29', () => _runCase(29, cases));
  test('xterm Keyboard 30', () => _runCase(30, cases));
  test('xterm Keyboard 31', () => _runCase(31, cases));
  test('xterm Keyboard 32', () => _runCase(32, cases));
  test('xterm Keyboard 33', () => _runCase(33, cases));
  test('xterm Keyboard 34', () => _runCase(34, cases));
  test('xterm Keyboard 35', () => _runCase(35, cases));
  test('xterm Keyboard 36', () => _runCase(36, cases));
  test('xterm Keyboard 37', () => _runCase(37, cases));
  test('xterm Keyboard 38', () => _runCase(38, cases));
  test('xterm Keyboard 39', () => _runCase(39, cases));
  test('xterm Keyboard 40', () => _runCase(40, cases));
  test('xterm Keyboard 41', () => _runCase(41, cases));
  test('xterm Keyboard 42', () => _runCase(42, cases));
  test('xterm Keyboard 43', () => _runCase(43, cases));
  test('xterm Keyboard 44', () => _runCase(44, cases));
  test('xterm Keyboard 45', () => _runCase(45, cases));
  test('xterm Keyboard 46', () => _runCase(46, cases));
  test('xterm Keyboard 47', () => _runCase(47, cases));
  test('xterm Keyboard 48', () => _runCase(48, cases));
  test('xterm Keyboard 49', () => _runCase(49, cases));
  test('xterm Keyboard 50', () => _runCase(50, cases));
  test('xterm Keyboard 51', () => _runCase(51, cases));
  test('xterm Keyboard 52', () => _runCase(52, cases));
  test('xterm Keyboard 53', () => _runCase(53, cases));
  test('xterm Keyboard 54', () => _runCase(54, cases));
  test('xterm Keyboard 55', () => _runCase(55, cases));
  test('xterm Keyboard 56', () => _runCase(56, cases));
  test('xterm Keyboard 57', () => _runCase(57, cases));
  test('xterm Keyboard 58', () => _runCase(58, cases));
  test('xterm Keyboard 59', () => _runCase(59, cases));
  test('xterm Keyboard 60', () => _runCase(60, cases));
}

void _runCase(int index, List<Map<String, Object?>> cases) {
  final evaluations = (cases[index]['evaluations']! as List<Object?>)
      .cast<Map<String, Object?>>();
  for (final value in evaluations) {
    final rawEvent = value['event']! as Map<String, Object?>;
    final expected = value['result']! as Map<String, Object?>;
    final result = evaluateKeyboardEvent(
      KittyKeyboardEvent(
        altKey: rawEvent['altKey']! as bool,
        ctrlKey: rawEvent['ctrlKey']! as bool,
        shiftKey: rawEvent['shiftKey']! as bool,
        metaKey: rawEvent['metaKey']! as bool,
        keyCode: rawEvent['keyCode']! as int,
        code: rawEvent['code']! as String,
        key: rawEvent['key']! as String,
        type: rawEvent['type']! as String,
      ),
      applicationCursorMode: value['applicationCursorMode']! as bool,
      isMac: value['isMac']! as bool,
      macOptionIsMeta: value['macOptionIsMeta']! as bool,
    );
    expect(result.type.index, expected['type']);
    expect(result.cancel, expected['cancel']);
    expect(result.key, expected['key']);
  }
}

List<Map<String, Object?>> _loadCases() {
  const relative = 'test/fixtures/xterm/keyboard_cases.json';
  final file = fixtureFile(relative);
  final document = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  if (document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb') {
    throw StateError('keyboard fixture revision changed');
  }
  return (document['cases']! as List<Object?>).cast<Map<String, Object?>>();
}
