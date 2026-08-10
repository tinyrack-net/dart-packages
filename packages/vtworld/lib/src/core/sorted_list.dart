/// A list maintained in ascending numeric-key order.
///
/// Inserts and deletions are batched until an operation needs a stable view,
/// matching xterm.js' `SortedList` observation boundaries.
final class SortedList<T> {
  /// Creates a sorted list using [_getKey] for ordering and lookup.
  SortedList(this._getKey);

  final num Function(T value) _getKey;
  List<T> _values = <T>[];
  final List<T> _insertedValues = <T>[];
  final List<int> _deletedIndices = <int>[];
  bool _isFlushingDeleted = false;

  /// Removes pending work and every stored value.
  void clear() {
    _values.clear();
    _insertedValues.clear();
    _deletedIndices.clear();
    _isFlushingDeleted = false;
  }

  /// Queues [value] for insertion.
  void insert(T value) {
    _flushCleanupDeleted();
    _insertedValues.add(value);
  }

  /// Deletes [value] by identity from its key bucket.
  bool delete(T value) {
    _flushCleanupInserted();
    if (_values.isEmpty) return false;
    final key = _getKey(value);
    var index = _search(key);
    if (index < 0 ||
        index >= _values.length ||
        _getKey(_values[index]) != key) {
      return false;
    }
    do {
      if (identical(_values[index], value)) {
        _deletedIndices.add(index);
        return true;
      }
      index++;
    } while (index < _values.length && _getKey(_values[index]) == key);
    return false;
  }

  /// Returns a snapshot iterator for values whose key equals [key].
  Iterable<T> getKeyIterator(num key) sync* {
    _flushCleanupInserted();
    _flushCleanupDeleted();
    if (_values.isEmpty) return;
    var index = _search(key);
    if (index < 0 ||
        index >= _values.length ||
        _getKey(_values[index]) != key) {
      return;
    }
    do {
      yield _values[index];
      index++;
    } while (index < _values.length && _getKey(_values[index]) == key);
  }

  /// Calls [callback] for values whose key equals [key].
  void forEachByKey(num key, void Function(T value) callback) =>
      getKeyIterator(key).forEach(callback);

  /// Returns an iteration snapshot that is unaffected by later mutations.
  Iterable<T> values() {
    _flushCleanupInserted();
    _flushCleanupDeleted();
    return List<T>.of(_values);
  }

  void _flushCleanupInserted() {
    if (_insertedValues.isEmpty) return;
    _insertedValues.sort((a, b) => _getKey(a).compareTo(_getKey(b)));
    final merged = <T>[];
    var insertedIndex = 0;
    var valueIndex = 0;
    while (insertedIndex < _insertedValues.length ||
        valueIndex < _values.length) {
      if (valueIndex >= _values.length ||
          (insertedIndex < _insertedValues.length &&
              _getKey(_insertedValues[insertedIndex]) <=
                  _getKey(_values[valueIndex]))) {
        merged.add(_insertedValues[insertedIndex++]);
      } else {
        merged.add(_values[valueIndex++]);
      }
    }
    _values = merged;
    _insertedValues.clear();
  }

  void _flushCleanupDeleted() {
    if (_isFlushingDeleted || _deletedIndices.isEmpty) return;
    _isFlushingDeleted = true;
    _deletedIndices.sort();
    final deleted = _deletedIndices.toSet();
    _values = <T>[
      for (var index = 0; index < _values.length; index++)
        if (!deleted.contains(index)) _values[index],
    ];
    _deletedIndices.clear();
    _isFlushingDeleted = false;
  }

  int _search(num key) {
    var min = 0;
    var max = _values.length - 1;
    while (max >= min) {
      var mid = (min + max) >> 1;
      final midKey = _getKey(_values[mid]);
      if (midKey > key) {
        max = mid - 1;
      } else if (midKey < key) {
        min = mid + 1;
      } else {
        while (mid > 0 && _getKey(_values[mid - 1]) == key) {
          mid--;
        }
        return mid;
      }
    }
    return min;
  }
}
