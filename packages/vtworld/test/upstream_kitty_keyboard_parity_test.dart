import 'dart:convert';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

import 'support/fixture_paths.dart';

void main() {
  final cases = _loadCases();
  test('xterm KittyKeyboard 000', () => _runCase(0, cases));
  test('xterm KittyKeyboard 001', () => _runCase(1, cases));
  test('xterm KittyKeyboard 002', () => _runCase(2, cases));
  test('xterm KittyKeyboard 003', () => _runCase(3, cases));
  test('xterm KittyKeyboard 004', () => _runCase(4, cases));
  test('xterm KittyKeyboard 005', () => _runCase(5, cases));
  test('xterm KittyKeyboard 006', () => _runCase(6, cases));
  test('xterm KittyKeyboard 007', () => _runCase(7, cases));
  test('xterm KittyKeyboard 008', () => _runCase(8, cases));
  test('xterm KittyKeyboard 009', () => _runCase(9, cases));
  test('xterm KittyKeyboard 010', () => _runCase(10, cases));
  test('xterm KittyKeyboard 011', () => _runCase(11, cases));
  test('xterm KittyKeyboard 012', () => _runCase(12, cases));
  test('xterm KittyKeyboard 013', () => _runCase(13, cases));
  test('xterm KittyKeyboard 014', () => _runCase(14, cases));
  test('xterm KittyKeyboard 015', () => _runCase(15, cases));
  test('xterm KittyKeyboard 016', () => _runCase(16, cases));
  test('xterm KittyKeyboard 017', () => _runCase(17, cases));
  test('xterm KittyKeyboard 018', () => _runCase(18, cases));
  test('xterm KittyKeyboard 019', () => _runCase(19, cases));
  test('xterm KittyKeyboard 020', () => _runCase(20, cases));
  test('xterm KittyKeyboard 021', () => _runCase(21, cases));
  test('xterm KittyKeyboard 022', () => _runCase(22, cases));
  test('xterm KittyKeyboard 023', () => _runCase(23, cases));
  test('xterm KittyKeyboard 024', () => _runCase(24, cases));
  test('xterm KittyKeyboard 025', () => _runCase(25, cases));
  test('xterm KittyKeyboard 026', () => _runCase(26, cases));
  test('xterm KittyKeyboard 027', () => _runCase(27, cases));
  test('xterm KittyKeyboard 028', () => _runCase(28, cases));
  test('xterm KittyKeyboard 029', () => _runCase(29, cases));
  test('xterm KittyKeyboard 030', () => _runCase(30, cases));
  test('xterm KittyKeyboard 031', () => _runCase(31, cases));
  test('xterm KittyKeyboard 032', () => _runCase(32, cases));
  test('xterm KittyKeyboard 033', () => _runCase(33, cases));
  test('xterm KittyKeyboard 034', () => _runCase(34, cases));
  test('xterm KittyKeyboard 035', () => _runCase(35, cases));
  test('xterm KittyKeyboard 036', () => _runCase(36, cases));
  test('xterm KittyKeyboard 037', () => _runCase(37, cases));
  test('xterm KittyKeyboard 038', () => _runCase(38, cases));
  test('xterm KittyKeyboard 039', () => _runCase(39, cases));
  test('xterm KittyKeyboard 040', () => _runCase(40, cases));
  test('xterm KittyKeyboard 041', () => _runCase(41, cases));
  test('xterm KittyKeyboard 042', () => _runCase(42, cases));
  test('xterm KittyKeyboard 043', () => _runCase(43, cases));
  test('xterm KittyKeyboard 044', () => _runCase(44, cases));
  test('xterm KittyKeyboard 045', () => _runCase(45, cases));
  test('xterm KittyKeyboard 046', () => _runCase(46, cases));
  test('xterm KittyKeyboard 047', () => _runCase(47, cases));
  test('xterm KittyKeyboard 048', () => _runCase(48, cases));
  test('xterm KittyKeyboard 049', () => _runCase(49, cases));
  test('xterm KittyKeyboard 050', () => _runCase(50, cases));
  test('xterm KittyKeyboard 051', () => _runCase(51, cases));
  test('xterm KittyKeyboard 052', () => _runCase(52, cases));
  test('xterm KittyKeyboard 053', () => _runCase(53, cases));
  test('xterm KittyKeyboard 054', () => _runCase(54, cases));
  test('xterm KittyKeyboard 055', () => _runCase(55, cases));
  test('xterm KittyKeyboard 056', () => _runCase(56, cases));
  test('xterm KittyKeyboard 057', () => _runCase(57, cases));
  test('xterm KittyKeyboard 058', () => _runCase(58, cases));
  test('xterm KittyKeyboard 059', () => _runCase(59, cases));
  test('xterm KittyKeyboard 060', () => _runCase(60, cases));
  test('xterm KittyKeyboard 061', () => _runCase(61, cases));
  test('xterm KittyKeyboard 062', () => _runCase(62, cases));
  test('xterm KittyKeyboard 063', () => _runCase(63, cases));
  test('xterm KittyKeyboard 064', () => _runCase(64, cases));
  test('xterm KittyKeyboard 065', () => _runCase(65, cases));
  test('xterm KittyKeyboard 066', () => _runCase(66, cases));
  test('xterm KittyKeyboard 067', () => _runCase(67, cases));
  test('xterm KittyKeyboard 068', () => _runCase(68, cases));
  test('xterm KittyKeyboard 069', () => _runCase(69, cases));
  test('xterm KittyKeyboard 070', () => _runCase(70, cases));
  test('xterm KittyKeyboard 071', () => _runCase(71, cases));
  test('xterm KittyKeyboard 072', () => _runCase(72, cases));
  test('xterm KittyKeyboard 073', () => _runCase(73, cases));
  test('xterm KittyKeyboard 074', () => _runCase(74, cases));
  test('xterm KittyKeyboard 075', () => _runCase(75, cases));
  test('xterm KittyKeyboard 076', () => _runCase(76, cases));
  test('xterm KittyKeyboard 077', () => _runCase(77, cases));
  test('xterm KittyKeyboard 078', () => _runCase(78, cases));
  test('xterm KittyKeyboard 079', () => _runCase(79, cases));
  test('xterm KittyKeyboard 080', () => _runCase(80, cases));
  test('xterm KittyKeyboard 081', () => _runCase(81, cases));
  test('xterm KittyKeyboard 082', () => _runCase(82, cases));
  test('xterm KittyKeyboard 083', () => _runCase(83, cases));
  test('xterm KittyKeyboard 084', () => _runCase(84, cases));
  test('xterm KittyKeyboard 085', () => _runCase(85, cases));
  test('xterm KittyKeyboard 086', () => _runCase(86, cases));
  test('xterm KittyKeyboard 087', () => _runCase(87, cases));
  test('xterm KittyKeyboard 088', () => _runCase(88, cases));
  test('xterm KittyKeyboard 089', () => _runCase(89, cases));
  test('xterm KittyKeyboard 090', () => _runCase(90, cases));
  test('xterm KittyKeyboard 091', () => _runCase(91, cases));
  test('xterm KittyKeyboard 092', () => _runCase(92, cases));
  test('xterm KittyKeyboard 093', () => _runCase(93, cases));
  test('xterm KittyKeyboard 094', () => _runCase(94, cases));
  test('xterm KittyKeyboard 095', () => _runCase(95, cases));
  test('xterm KittyKeyboard 096', () => _runCase(96, cases));
  test('xterm KittyKeyboard 097', () => _runCase(97, cases));
  test('xterm KittyKeyboard 098', () => _runCase(98, cases));
  test('xterm KittyKeyboard 099', () => _runCase(99, cases));
  test('xterm KittyKeyboard 100', () => _runCase(100, cases));
  test('xterm KittyKeyboard 101', () => _runCase(101, cases));
  test('xterm KittyKeyboard 102', () => _runCase(102, cases));
  test('xterm KittyKeyboard 103', () => _runCase(103, cases));
  test('xterm KittyKeyboard 104', () => _runCase(104, cases));
  test('xterm KittyKeyboard 105', () => _runCase(105, cases));
  test('xterm KittyKeyboard 106', () => _runCase(106, cases));
  test('xterm KittyKeyboard 107', () => _runCase(107, cases));
  test('xterm KittyKeyboard 108', () => _runCase(108, cases));
  test('xterm KittyKeyboard 109', () => _runCase(109, cases));
  test('xterm KittyKeyboard 110', () => _runCase(110, cases));
  test('xterm KittyKeyboard 111', () => _runCase(111, cases));
  test('xterm KittyKeyboard 112', () => _runCase(112, cases));
  test('xterm KittyKeyboard 113', () => _runCase(113, cases));
  test('xterm KittyKeyboard 114', () => _runCase(114, cases));
  test('xterm KittyKeyboard 115', () => _runCase(115, cases));
  test('xterm KittyKeyboard 116', () => _runCase(116, cases));
  test('xterm KittyKeyboard 117', () => _runCase(117, cases));
  test('xterm KittyKeyboard 118', () => _runCase(118, cases));
  test('xterm KittyKeyboard 119', () => _runCase(119, cases));
  test('xterm KittyKeyboard 120', () => _runCase(120, cases));
  test('xterm KittyKeyboard 121', () => _runCase(121, cases));
  test('xterm KittyKeyboard 122', () => _runCase(122, cases));
  test('xterm KittyKeyboard 123', () => _runCase(123, cases));
  test('xterm KittyKeyboard 124', () => _runCase(124, cases));
  test('xterm KittyKeyboard 125', () => _runCase(125, cases));
  test('xterm KittyKeyboard 126', () => _runCase(126, cases));
  test('xterm KittyKeyboard 127', () => _runCase(127, cases));
  test('xterm KittyKeyboard 128', () => _runCase(128, cases));
  test('xterm KittyKeyboard 129', () => _runCase(129, cases));
  test('xterm KittyKeyboard 130', () => _runCase(130, cases));
  test('xterm KittyKeyboard 131', () => _runCase(131, cases));
  test('xterm KittyKeyboard 132', () => _runCase(132, cases));
  test('xterm KittyKeyboard 133', () => _runCase(133, cases));
  test('xterm KittyKeyboard 134', () => _runCase(134, cases));
  test('xterm KittyKeyboard 135', () => _runCase(135, cases));
  test('xterm KittyKeyboard 136', () => _runCase(136, cases));
  test('xterm KittyKeyboard 137', () => _runCase(137, cases));
  test('xterm KittyKeyboard 138', () => _runCase(138, cases));
  test('xterm KittyKeyboard 139', () => _runCase(139, cases));
  test('xterm KittyKeyboard 140', () => _runCase(140, cases));
  test('xterm KittyKeyboard 141', () => _runCase(141, cases));
  test('xterm KittyKeyboard 142', () => _runCase(142, cases));
  test('xterm KittyKeyboard 143', () => _runCase(143, cases));
  test('xterm KittyKeyboard 144', () => _runCase(144, cases));
  test('xterm KittyKeyboard 145', () => _runCase(145, cases));
  test('xterm KittyKeyboard 146', () => _runCase(146, cases));
  test('xterm KittyKeyboard 147', () => _runCase(147, cases));
  test('xterm KittyKeyboard 148', () => _runCase(148, cases));
  test('xterm KittyKeyboard 149', () => _runCase(149, cases));
  test('xterm KittyKeyboard 150', () => _runCase(150, cases));
  test('xterm KittyKeyboard 151', () => _runCase(151, cases));
  test('xterm KittyKeyboard 152', () => _runCase(152, cases));
  test('xterm KittyKeyboard 153', () => _runCase(153, cases));
  test('xterm KittyKeyboard 154', () => _runCase(154, cases));
  test('xterm KittyKeyboard 155', () => _runCase(155, cases));
  test('xterm KittyKeyboard 156', () => _runCase(156, cases));
  test('xterm KittyKeyboard 157', () => _runCase(157, cases));
  test('xterm KittyKeyboard 158', () => _runCase(158, cases));
  test('xterm KittyKeyboard 159', () => _runCase(159, cases));
  test('xterm KittyKeyboard 160', () => _runCase(160, cases));
  test('xterm KittyKeyboard 161', () => _runCase(161, cases));
  test('xterm KittyKeyboard 162', () => _runCase(162, cases));
  test('xterm KittyKeyboard 163', () => _runCase(163, cases));
  test('xterm KittyKeyboard 164', () => _runCase(164, cases));
}

void _runCase(int index, List<Map<String, Object?>> cases) {
  final value = cases[index];
  final evaluations = (value['evaluations']! as List<Object?>)
      .cast<Map<String, Object?>>();
  if (evaluations.isEmpty) {
    if (index == 0) {
      expect(KittyKeyboard.shouldUseProtocol(KittyKeyboardFlags.none), isFalse);
    } else {
      expect(
        KittyKeyboard.shouldUseProtocol(
          KittyKeyboardFlags.disambiguateEscapeCodes,
        ),
        isTrue,
      );
      expect(
        KittyKeyboard.shouldUseProtocol(KittyKeyboardFlags.reportEventTypes),
        isTrue,
      );
      expect(KittyKeyboard.shouldUseProtocol(0x1f), isTrue);
    }
    return;
  }
  final keyboard = KittyKeyboard();
  for (final evaluation in evaluations) {
    final rawEvent = evaluation['event']! as Map<String, Object?>;
    final expected = evaluation['result']! as Map<String, Object?>;
    final result = keyboard.evaluate(
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
      evaluation['flags']! as int,
      eventType: KittyKeyboardEventType.values.firstWhere(
        (type) => type.value == evaluation['eventType'],
      ),
      macOptionAsAlt: evaluation['macOptionAsAlt']! as bool,
    );
    expect(result.type.index, expected['type']);
    expect(result.cancel, expected['cancel']);
    expect(result.key, expected['key']);
  }
}

List<Map<String, Object?>> _loadCases() {
  const relative = 'test/fixtures/xterm/kitty_keyboard_cases.json';
  final file = fixtureFile(relative);
  final document = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  if (document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb') {
    throw StateError('Kitty keyboard fixture revision changed');
  }
  return (document['cases']! as List<Object?>).cast<Map<String, Object?>>();
}
