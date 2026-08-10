import 'package:vtworld/src/core/addon.dart';
import 'package:vtworld/src/core/terminal.dart';

/// Common one-shot activation and disposal behavior for official addons.
abstract class ManagedTerminalAddon extends TerminalAddon {
  Terminal? _terminal;

  /// The terminal after activation.
  Terminal get terminal =>
      _terminal ??
      (throw StateError('Cannot use addon until it has been loaded'));

  /// Whether [activate] has completed.
  bool get isActive => _terminal != null;

  @override
  void activate(Terminal terminal) {
    if (isDisposed) throw StateError('Cannot activate a disposed addon');
    if (_terminal != null) throw StateError('Addon is already loaded');
    _terminal = terminal;
    onActivate(terminal);
  }

  /// Installs handlers into [terminal].
  void onActivate(Terminal terminal);

  @override
  void dispose() {
    if (isDisposed) return;
    _terminal = null;
    super.dispose();
  }
}
