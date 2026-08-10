/// Headless xterm-compatible VT parsing, cell grid, and ANSI serialization.
///
/// This is the terminal emulator without a renderer: it turns pseudo-terminal
/// output into a cell grid and can serialize that grid back into ANSI that
/// reproduces it in a reset terminal. A server holds one per session so a
/// client that reconnects is handed a screen rather than a byte log.
library;

export 'src/addons/managed_addon.dart';
export 'src/addons/serialize.dart';
export 'src/core/addon.dart';
export 'src/core/buffer.dart';
export 'src/core/buffer_line_string_cache.dart';
export 'src/core/character_joiner_service.dart';
export 'src/core/clipboard.dart';
export 'src/core/color_zone_store.dart';
export 'src/core/decoration_service.dart';
export 'src/core/disposable.dart';
export 'src/core/event.dart';
export 'src/core/keyboard.dart';
export 'src/core/kitty_keyboard.dart';
export 'src/core/marker.dart';
export 'src/core/mouse_coordinates.dart';
export 'src/core/move_to_cell.dart';
export 'src/core/options.dart';
export 'src/core/parser.dart';
export 'src/core/renderer_utils.dart';
export 'src/core/selection_service.dart';
export 'src/core/terminal.dart';
export 'src/core/text_blink_state_manager.dart';
export 'src/core/text_decoder.dart';
export 'src/core/unicode.dart';
export 'src/core/windows_mode.dart';
export 'src/core/write_buffer.dart';
