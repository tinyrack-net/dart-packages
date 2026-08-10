import 'dart:typed_data';

/// Parser parameter storage with xterm's fixed limits and subparameter model.
final class Params {
  /// Creates storage for [maxLength] parameters and [maxSubParamsLength]
  /// subparameters.
  Params({this.maxLength = 32, this.maxSubParamsLength = 32})
    : params = Int32List(maxLength),
      _subParams = Int32List(maxSubParamsLength),
      _subParamsIndex = Uint16List(maxLength) {
    if (maxSubParamsLength > 256) {
      throw ArgumentError.value(
        maxSubParamsLength,
        'maxSubParamsLength',
        'must not be greater than 256',
      );
    }
  }

  /// Creates parameter storage from its nested-array representation.
  factory Params.fromArray(List<Object> values) {
    final result = Params();
    if (values.isEmpty) return result;
    final start = values.first is List<Object> ? 1 : 0;
    for (var index = start; index < values.length; index++) {
      final value = values[index];
      if (value is List<Object>) {
        for (final subParameter in value) {
          result.addSubParam(subParameter as int);
        }
      } else {
        result.addParam(value as int);
      }
    }
    return result;
  }

  static const int _maximumValue = 0x7fffffff;

  /// Maximum stored parameter count.
  final int maxLength;

  /// Maximum stored subparameter count.
  final int maxSubParamsLength;

  /// Parameter backing store.
  final Int32List params;

  final Int32List _subParams;
  final Uint16List _subParamsIndex;
  int _subParamsLength = 0;
  bool _rejectDigits = false;
  bool _rejectSubDigits = false;
  bool _digitIsSub = false;

  /// Current parameter count.
  int length = 0;

  /// Current subparameter count.
  int get subParamsLength => _subParamsLength;

  /// Subparameter backing storage, exposed for conformance inspection.
  Int32List get subParams => _subParams;

  /// Creates an independent copy of all state.
  Params clone() {
    final result = Params(
      maxLength: maxLength,
      maxSubParamsLength: maxSubParamsLength,
    );
    result.params.setAll(0, params);
    result
      ..length = length
      .._subParams.setAll(0, _subParams)
      .._subParamsLength = _subParamsLength
      .._subParamsIndex.setAll(0, _subParamsIndex)
      .._rejectDigits = _rejectDigits
      .._rejectSubDigits = _rejectSubDigits
      .._digitIsSub = _digitIsSub;
    return result;
  }

  /// Converts stored values to xterm's nested-array representation.
  List<Object> toArray() {
    final result = <Object>[];
    for (var index = 0; index < length; index++) {
      result.add(params[index]);
      final start = _subParamsIndex[index] >> 8;
      final end = _subParamsIndex[index] & 0xff;
      if (end > start) {
        result.add(<int>[
          for (var subIndex = start; subIndex < end; subIndex++)
            _subParams[subIndex],
        ]);
      }
    }
    return result;
  }

  /// Resets to an empty state.
  void reset() {
    length = 0;
    _subParamsLength = 0;
    _rejectDigits = false;
    _rejectSubDigits = false;
    _digitIsSub = false;
  }

  /// Resets with a single zero parameter for zero-default mode.
  void resetZdm() {
    length = 1;
    _subParamsLength = 0;
    _rejectDigits = false;
    _rejectSubDigits = false;
    _digitIsSub = false;
    _subParamsIndex[0] = 0;
    params[0] = 0;
  }

  /// Adds a complete parameter.
  void addParam(int value) {
    _digitIsSub = false;
    if (length >= maxLength) {
      _rejectDigits = true;
      return;
    }
    _validate(value);
    _subParamsIndex[length] = _subParamsLength << 8 | _subParamsLength;
    params[length++] = value > _maximumValue ? _maximumValue : value;
  }

  /// Adds a complete subparameter to the final parameter.
  void addSubParam(int value) {
    _digitIsSub = true;
    if (length == 0) return;
    if (_rejectDigits || _subParamsLength >= maxSubParamsLength) {
      _rejectSubDigits = true;
      return;
    }
    _validate(value);
    _subParams[_subParamsLength++] = value > _maximumValue
        ? _maximumValue
        : value;
    _subParamsIndex[length - 1]++;
  }

  /// Whether parameter [index] owns subparameters.
  bool hasSubParams(int index) {
    final packed = _subParamsIndex[index];
    return (packed & 0xff) - (packed >> 8) > 0;
  }

  /// Returns the borrowed subparameter view for [index].
  Int32List? getSubParams(int index) {
    final packed = _subParamsIndex[index];
    final start = packed >> 8;
    final end = packed & 0xff;
    return end > start ? Int32List.sublistView(_subParams, start, end) : null;
  }

  /// Returns independent subparameter copies indexed by parameter.
  Map<int, Int32List> getSubParamsAll() => <int, Int32List>{
    for (var index = 0; index < length; index++)
      if (getSubParams(index) case final values?)
        index: Int32List.fromList(values),
  };

  /// Adds one decimal [digit] to the active parameter or subparameter.
  void addDigit(int digit) {
    final activeLength = _digitIsSub ? _subParamsLength : length;
    if (_rejectDigits ||
        activeLength == 0 ||
        (_digitIsSub && _rejectSubDigits)) {
      return;
    }
    final store = _digitIsSub ? _subParams : params;
    final current = store[activeLength - 1];
    store[activeLength - 1] = current == -1
        ? digit
        : (current * 10 + digit).clamp(0, _maximumValue);
  }

  void _validate(int value) {
    if (value < -1) {
      throw ArgumentError.value(value, 'value', 'must not be less than -1');
    }
  }
}
