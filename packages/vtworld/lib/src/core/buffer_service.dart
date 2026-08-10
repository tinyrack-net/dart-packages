import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';
import 'package:vtworld/src/core/options.dart';

/// Minimum dimensions enforced by xterm's common buffer service.
abstract final class BufferServiceConstants {
  /// Fewer columns can split wide cells incorrectly.
  static const int minimumColumns = 2;

  /// A terminal always retains at least one viewport row.
  static const int minimumRows = 1;
}

/// Dimension change emitted by [TerminalBufferService].
final class BufferServiceResizeEvent {
  /// Creates a resize event with independent change flags.
  const BufferServiceResizeEvent({
    required this.columns,
    required this.rows,
    required this.columnsChanged,
    required this.rowsChanged,
  });

  /// New column count.
  final int columns;

  /// New row count.
  final int rows;

  /// Whether [columns] differs from the previous value.
  final bool columnsChanged;

  /// Whether [rows] differs from the previous value.
  final bool rowsChanged;
}

/// Owns xterm's normal/alternate buffers and viewport scroll state.
final class TerminalBufferService extends DisposableStore {
  /// Creates buffers from [options], enforcing xterm's minimum dimensions.
  TerminalBufferService(TerminalOptions options)
    : columns = options.cols < BufferServiceConstants.minimumColumns
          ? BufferServiceConstants.minimumColumns
          : options.cols,
      rows = options.rows < BufferServiceConstants.minimumRows
          ? BufferServiceConstants.minimumRows
          : options.rows,
      _scrollback = options.scrollback {
    buffers = add(
      TerminalBufferNamespace(
        columns: columns,
        rows: rows,
        scrollback: _scrollback,
      ),
    );
    scrollBottom = rows - 1;
    add(_onResize);
    add(_onScroll);
    add(
      buffers.onBufferActivate.listen((event) {
        displayY = event.activeBuffer.baseY;
        event.activeBuffer.displayY = displayY;
        _onScroll.fire(displayY);
      }),
    );
  }

  /// Current column count.
  int columns;

  /// Current row count.
  int rows;

  /// Normal and alternate buffers.
  late final TerminalBufferNamespace buffers;

  /// Whether the user has scrolled away from the live bottom.
  bool isUserScrolling = false;

  /// Absolute row displayed at the top of the viewport.
  int displayY = 0;

  /// First viewport-relative row of the scrolling region.
  int scrollTop = 0;

  /// Last viewport-relative row of the scrolling region.
  late int scrollBottom;

  final int _scrollback;
  final TerminalEventEmitter<BufferServiceResizeEvent> _onResize =
      TerminalEventEmitter<BufferServiceResizeEvent>();
  final TerminalEventEmitter<int> _onScroll = TerminalEventEmitter<int>();

  /// Active terminal buffer.
  TerminalBuffer get buffer => buffers.active;

  /// Fires synchronously after every service resize request.
  TerminalEvent<BufferServiceResizeEvent> get onResize => _onResize.event;

  /// Fires when the displayed absolute row changes or content scrolls.
  TerminalEvent<int> get onScroll => _onScroll.event;

  /// Resizes both buffers and emits which dimensions changed.
  void resize(int newColumns, int newRows) {
    final columnsChanged = columns != newColumns;
    final rowsChanged = rows != newRows;
    columns = newColumns;
    rows = newRows;
    scrollBottom = newRows - 1;
    buffers.resize(newColumns, newRows, TerminalCellAttributes());
    displayY = displayY.clamp(0, buffer.baseY);
    buffer.displayY = displayY;
    _onResize.fire(
      BufferServiceResizeEvent(
        columns: newColumns,
        rows: newRows,
        columnsChanged: columnsChanged,
        rowsChanged: rowsChanged,
      ),
    );
  }

  /// Replaces both buffers and clears user-scrolling state.
  void reset() {
    buffers.reset();
    isUserScrolling = false;
    displayY = 0;
    buffer.displayY = 0;
    scrollTop = 0;
    scrollBottom = rows - 1;
  }

  /// Scrolls terminal content down one row using [eraseAttributes].
  void scroll(
    TerminalCellAttributes eraseAttributes, {
    bool isWrapped = false,
  }) {
    final active = buffer;
    final wasFull =
        active.type == TerminalBufferType.normal &&
        active.length >= rows + _scrollback;
    active.scroll(eraseAttributes, top: scrollTop, bottom: scrollBottom);
    active.getLine(active.baseY + scrollBottom)!.isWrapped = isWrapped;
    if (scrollTop == 0) {
      if (wasFull && isUserScrolling) {
        displayY = (displayY - 1).clamp(0, active.baseY);
      } else if (!isUserScrolling) {
        displayY = active.baseY;
      }
    }
    if (!isUserScrolling) displayY = active.baseY;
    active.displayY = displayY;
    _onScroll.fire(displayY);
  }

  /// Moves the display within retained history.
  void scrollLines(int amount, {bool suppressScrollEvent = false}) {
    final active = buffer;
    if (amount < 0) {
      if (displayY == 0) return;
      isUserScrolling = true;
    } else if (amount + displayY >= active.baseY) {
      isUserScrolling = false;
    }
    final oldDisplayY = displayY;
    displayY = (displayY + amount).clamp(0, active.baseY);
    if (displayY == oldDisplayY) {
      active.displayY = displayY;
      return;
    }
    active.displayY = displayY;
    if (!suppressScrollEvent) _onScroll.fire(displayY);
  }
}
