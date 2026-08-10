import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/terminal.dart';

/// Extension loaded into a terminal instance.
abstract class TerminalAddon extends DisposableStore {
  final List<void Function()> _disposeListeners = <void Function()>[];

  /// Activates this addon. It is called at most once.
  void activate(Terminal terminal);

  /// Registers an internal notification used by the addon manager.
  Disposable addDisposeListener(void Function() listener) {
    _disposeListeners.add(listener);
    return toDisposable(() => _disposeListeners.remove(listener));
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    final listeners = List<void Function()>.of(_disposeListeners);
    _disposeListeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}
