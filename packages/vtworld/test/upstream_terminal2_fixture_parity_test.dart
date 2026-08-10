import 'dart:io';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

import 'support/fixture_paths.dart';

void main() {
  group('Escape Sequence Files pinned upstream corpus', () {
    test('t0001-all_printable.in', () => _verifyFixture('t0001-all_printable'));
    test('t0002-history.in', () => _verifyFixture('t0002-history'));
    test(
      't0002j-simple_string.in',
      () => _verifyFixture('t0002j-simple_string'),
    );
    test('t0003-line_wrap.in', () => _verifyFixture('t0003-line_wrap'));
    test('t0003j-LF.in', () => _verifyFixture('t0003j-LF'));
    test('t0004-LF.in', () => _verifyFixture('t0004-LF'));
    test('t0004j-CR.in', () => _verifyFixture('t0004j-CR'));
    test('t0005-CR.in', () => _verifyFixture('t0005-CR'));
    test('t0006-IND.in', () => _verifyFixture('t0006-IND'));
    test('t0007-space_at_end.in', () => _verifyFixture('t0007-space_at_end'));
    test('t0008-BS.in', () => _verifyFixture('t0008-BS'));
    test('t0009-NEL.in', () => _verifyFixture('t0009-NEL'));
    test('t0010-RI.in', () => _verifyFixture('t0010-RI'));
    test('t0011-RI_scroll.in', () => _verifyFixture('t0011-RI_scroll'));
    test('t0012-VT.in', () => _verifyFixture('t0012-VT'));
    test('t0013-FF.in', () => _verifyFixture('t0013-FF'));
    test('t0014-CAN.in', () => _verifyFixture('t0014-CAN'));
    test('t0015-SUB.in', () => _verifyFixture('t0015-SUB'));
    test('t0016-SU.in', () => _verifyFixture('t0016-SU'));
    test('t0017-SD.in', () => _verifyFixture('t0017-SD'));
    test('t0020-CUF.in', () => _verifyFixture('t0020-CUF'));
    test('t0021-CUB.in', () => _verifyFixture('t0021-CUB'));
    test('t0022-CUU.in', () => _verifyFixture('t0022-CUU'));
    test('t0023-CUU_scroll.in', () => _verifyFixture('t0023-CUU_scroll'));
    test('t0024-CUD.in', () => _verifyFixture('t0024-CUD'));
    test('t0025-CUP.in', () => _verifyFixture('t0025-CUP'));
    test('t0026-CNL.in', () => _verifyFixture('t0026-CNL'));
    test('t0027-CPL.in', () => _verifyFixture('t0027-CPL'));
    test('t0030-HPR.in', () => _verifyFixture('t0030-HPR'));
    test('t0032-VPB.in', () => _verifyFixture('t0032-VPB'));
    test('t0033-VPB_scroll.in', () => _verifyFixture('t0033-VPB_scroll'));
    test('t0034-VPR.in', () => _verifyFixture('t0034-VPR'));
    test('t0035-HVP.in', () => _verifyFixture('t0035-HVP'));
    test('t0040-REP.in', () => _verifyFixture('t0040-REP'));
    test('t0050-ICH.in', () => _verifyFixture('t0050-ICH'));
    test('t0051-IL.in', () => _verifyFixture('t0051-IL'));
    test('t0052-DL.in', () => _verifyFixture('t0052-DL'));
    test('t0053-DCH.in', () => _verifyFixture('t0053-DCH'));
    test('t0054-ECH.in', () => _verifyFixture('t0054-ECH'));
    test('t0056-ED.in', () => _verifyFixture('t0056-ED'));
    test('t0057-ED3.in', () => _verifyFixture('t0057-ED3'));
    test('t0060-DECSC.in', () => _verifyFixture('t0060-DECSC'));
    test('t0061-CSI_s.in', () => _verifyFixture('t0061-CSI_s'));
    test('t0070-DECSTBM_LF.in', () => _verifyFixture('t0070-DECSTBM_LF'));
    test('t0071-DECSTBM_IND.in', () => _verifyFixture('t0071-DECSTBM_IND'));
    test('t0072-DECSTBM_NEL.in', () => _verifyFixture('t0072-DECSTBM_NEL'));
    test('t0073-DECSTBM_RI.in', () => _verifyFixture('t0073-DECSTBM_RI'));
    test('t0074-DECSTBM_SU_SD.in', () => _verifyFixture('t0074-DECSTBM_SU_SD'));
    test(
      't0075-DECSTBM_CUU_CUD.in',
      () => _verifyFixture('t0075-DECSTBM_CUU_CUD'),
    );
    test('t0076-DECSTBM_IL_DL.in', () => _verifyFixture('t0076-DECSTBM_IL_DL'));
    test(
      't0077-DECSTBM_quirks.in',
      () => _verifyFixture('t0077-DECSTBM_quirks'),
    );
    test(
      't0078-DECSTBM_CPL_CNL.in',
      () => _verifyFixture('t0078-DECSTBM_CPL_CNL'),
    );
    test('t0079-DECSTBM_VPR.in', () => _verifyFixture('t0079-DECSTBM_VPR'));
    test('t0080-HT.in', () => _verifyFixture('t0080-HT'));
    test('t0081-TBC.in', () => _verifyFixture('t0081-TBC'));
    test('t0082-HTS.in', () => _verifyFixture('t0082-HTS'));
    test('t0083-CHT.in', () => _verifyFixture('t0083-CHT'));
    test('t0090-alt_screen.in', () => _verifyFixture('t0090-alt_screen'));
    test(
      't0091-alt_screen_ED3.in',
      () => _verifyFixture('t0091-alt_screen_ED3'),
    );
    test(
      't0092-alt_screen_DECSC.in',
      () => _verifyFixture('t0092-alt_screen_DECSC'),
    );
    test('t0100-IRM.in', () => _verifyFixture('t0100-IRM'));
    test('t0102-DECAWM.in', () => _verifyFixture('t0102-DECAWM'));
    test('t0300-vttest1.in', () => _verifyFixture('t0300-vttest1'));
    test(
      't0500-bash_long_line.in',
      () => _verifyFixture('t0500-bash_long_line'),
    );
    test('t0501-bash_ls.in', () => _verifyFixture('t0501-bash_ls'));
    test('t0502-bash_ls_color.in', () => _verifyFixture('t0502-bash_ls_color'));
    test('t0503-zsh_ls_color.in', () => _verifyFixture('t0503-zsh_ls_color'));
    test('t600-DECSTBM_SR.in', () => _verifyFixture('t600-DECSTBM_SR'));
    test('t601-DECSTBM_SL.in', () => _verifyFixture('t601-DECSTBM_SL'));
    test('t602-DECSTBM_DECIC.in', () => _verifyFixture('t602-DECSTBM_DECIC'));
    test('t603-DECSTBM_DECDC.in', () => _verifyFixture('t603-DECSTBM_DECDC'));
  });
}

Future<void> _verifyFixture(String name) async {
  final root = fixtureDirectory('test/fixtures/xterm/escape_sequence_files');
  final input = File('${root.path}/$name.in');
  final pinnedRoot = fixturePath('test/fixtures/xterm_pinned_outputs');
  final pinned = File('$pinnedRoot/$name.text');
  final expected = pinned.existsSync()
      ? pinned
      : File('${root.path}/$name.text');
  expect(input.existsSync(), isTrue, reason: '$name input fixture is missing');
  expect(
    expected.existsSync(),
    isTrue,
    reason: '$name expected fixture is missing',
  );

  final terminal = Terminal(options: TerminalOptions(rows: 25, scrollback: 0));
  try {
    await terminal.writeAndWait(
      input.readAsStringSync().replaceAll('\n', '\r\n'),
    );
    final actual = StringBuffer();
    final start = terminal.buffer.active.baseY;
    for (var row = 0; row < 25; row++) {
      actual.writeln(
        terminal.buffer.active
            .getLine(start + row)!
            .translateToString(trimRight: true)
            .trimRight(),
      );
    }
    final expectedRightTrimmed = expected
        .readAsStringSync()
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n');
    expect(actual.toString(), expectedRightTrimmed);
  } finally {
    terminal.dispose();
  }
}
