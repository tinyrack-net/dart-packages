import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';

/// A contiguous insertion or deletion in a circular list.
final class CircularListChange {
  /// Creates a change beginning at [index] spanning [amount] values.
  const CircularListChange({required this.index, required this.amount});

  /// Logical start index.
  final int index;

  /// Number of changed values.
  final int amount;
}

/// A maximum-size list that overwrites values from the front when full.
final class CircularList<T> extends DisposableStore {
  /// Creates an empty circular list with [maxLength] backing slots.
  CircularList(int maxLength)
    : _maxLength = maxLength,
      _array = List<T?>.filled(maxLength, null) {
    add(_onDeleteEmitter);
    add(_onInsertEmitter);
    add(_onTrimEmitter);
  }

  List<T?> _array;
  int _startIndex = 0;
  int _length = 0;
  int _maxLength;

  final TerminalEventEmitter<CircularListChange> _onDeleteEmitter =
      TerminalEventEmitter<CircularListChange>();
  final TerminalEventEmitter<CircularListChange> _onInsertEmitter =
      TerminalEventEmitter<CircularListChange>();
  final TerminalEventEmitter<int> _onTrimEmitter = TerminalEventEmitter<int>();

  /// Fires after logical values are deleted.
  TerminalEvent<CircularListChange> get onDelete => _onDeleteEmitter.event;

  /// Fires after logical values are inserted.
  TerminalEvent<CircularListChange> get onInsert => _onInsertEmitter.event;

  /// Fires with the number of values trimmed from the start.
  TerminalEvent<int> get onTrim => _onTrimEmitter.event;

  /// Maximum number of retained values.
  int get maxLength => _maxLength;
  set maxLength(int value) {
    if (_maxLength == value) return;
    final next = List<T?>.filled(value, null);
    final transferred = value < length ? value : length;
    for (var index = 0; index < transferred; index++) {
      next[index] = _array[_cyclicIndex(index)];
    }
    _array = next;
    _maxLength = value;
    _startIndex = 0;
  }

  /// Number of logical values.
  int get length => _length;
  set length(int value) {
    if (value > _length) {
      for (var index = _length; index < value; index++) {
        _array[index] = null;
      }
    }
    _length = value;
  }

  /// Whether the list has reached [maxLength].
  bool get isFull => _length == _maxLength;

  /// Returns the value at logical [index].
  T? get(int index) => _array[_cyclicIndex(index)];

  /// Sets the value at logical [index].
  void set(int index, T? value) => _array[_cyclicIndex(index)] = value;

  /// Appends [value], trimming one value from the front when full.
  void push(T value) {
    _array[_cyclicIndex(_length)] = value;
    if (_length == _maxLength) {
      _startIndex = (_startIndex + 1) % _maxLength;
      _onTrimEmitter.fire(1);
    } else {
      _length++;
    }
  }

  /// Advances a full buffer and returns the newly reusable final value.
  T recycle() {
    if (_length != _maxLength) {
      throw StateError('Can only recycle when the buffer is full');
    }
    _startIndex = (_startIndex + 1) % _maxLength;
    _onTrimEmitter.fire(1);
    return _array[_cyclicIndex(_length - 1)] as T;
  }

  /// Removes and returns the final value.
  T? pop() => _array[_cyclicIndex(_length-- - 1)];

  /// Deletes [deleteCount] values at [start], then inserts [items].
  void splice(int start, int deleteCount, [List<T> items = const []]) {
    if (deleteCount != 0) {
      for (var index = start; index < _length - deleteCount; index++) {
        _array[_cyclicIndex(index)] = _array[_cyclicIndex(index + deleteCount)];
      }
      _length -= deleteCount;
      _onDeleteEmitter.fire(
        CircularListChange(index: start, amount: deleteCount),
      );
    }

    for (var index = _length - 1; index >= start; index--) {
      _array[_cyclicIndex(index + items.length)] = _array[_cyclicIndex(index)];
    }
    for (var index = 0; index < items.length; index++) {
      _array[_cyclicIndex(start + index)] = items[index];
    }
    if (items.isNotEmpty) {
      _onInsertEmitter.fire(
        CircularListChange(index: start, amount: items.length),
      );
    }

    if (_length + items.length > _maxLength) {
      final trimCount = _length + items.length - _maxLength;
      _startIndex += trimCount;
      _length = _maxLength;
      _onTrimEmitter.fire(trimCount);
    } else {
      _length += items.length;
    }
  }

  /// Removes up to [count] values from the front.
  void trimStart(int count) {
    final amount = count > _length ? _length : count;
    _startIndex += amount;
    _length -= amount;
    _onTrimEmitter.fire(amount);
  }

  /// Copies [count] values at [start] by [offset] logical positions.
  void shiftElements(int start, int count, int offset) {
    if (count <= 0) return;
    if (start < 0 || start >= _length) {
      throw RangeError('start argument out of range');
    }
    if (start + offset < 0) {
      throw RangeError('Cannot shift elements in list beyond index 0');
    }
    if (offset > 0) {
      for (var index = count - 1; index >= 0; index--) {
        set(start + index + offset, get(start + index));
      }
      final expansion = start + count + offset - _length;
      if (expansion > 0) {
        _length += expansion;
        while (_length > _maxLength) {
          _length--;
          _startIndex++;
          _onTrimEmitter.fire(1);
        }
      }
    } else {
      for (var index = 0; index < count; index++) {
        set(start + index + offset, get(start + index));
      }
    }
  }

  int _cyclicIndex(int index) => (_startIndex + index) % _maxLength;
}
