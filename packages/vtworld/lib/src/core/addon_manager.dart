import 'package:vtworld/src/core/addon.dart';
import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/terminal.dart';

final class _LoadedAddon {
  _LoadedAddon(this.instance);

  final TerminalAddon instance;
  Disposable? disposeListener;
  bool isDisposed = false;
}

/// Owns terminal addons and mirrors xterm's disposal wrapping semantics.
final class AddonManager implements Disposable {
  final List<_LoadedAddon> _addons = <_LoadedAddon>[];
  bool _isDisposed = false;

  /// Number of addons that have not disposed themselves.
  int get loadedAddonCount => _addons.length;

  /// Activates and begins tracking [instance].
  void loadAddon(Terminal terminal, TerminalAddon instance) {
    final loadedAddon = _LoadedAddon(instance);
    _addons.add(loadedAddon);
    loadedAddon.disposeListener = instance.addDisposeListener(
      () => _wrappedAddonDispose(loadedAddon),
    );
    instance.activate(terminal);
  }

  void _wrappedAddonDispose(_LoadedAddon loadedAddon) {
    if (loadedAddon.isDisposed) return;
    final index = _addons.indexOf(loadedAddon);
    if (index == -1) {
      throw StateError('Could not dispose an addon that has not been loaded');
    }
    loadedAddon.isDisposed = true;
    loadedAddon.disposeListener?.dispose();
    loadedAddon.disposeListener = null;
    _addons.removeAt(index);
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    for (final addon in List<_LoadedAddon>.of(_addons).reversed) {
      addon.instance.dispose();
    }
    _isDisposed = true;
  }
}
