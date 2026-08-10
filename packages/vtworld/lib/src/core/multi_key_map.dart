/// A map addressed by two independent keys.
final class TwoKeyMap<K1 extends Object, K2 extends Object, V> {
  Map<K1, Map<K2, V>> _data = <K1, Map<K2, V>>{};

  /// Stores [value] at ([first], [second]).
  void set(K1 first, K2 second, V value) {
    (_data[first] ??= <K2, V>{})[second] = value;
  }

  /// Looks up the value at ([first], [second]).
  V? get(K1 first, K2 second) => _data[first]?[second];

  /// Removes all entries.
  void clear() => _data = <K1, Map<K2, V>>{};
}

/// A map addressed by four independent keys.
final class FourKeyMap<
  K1 extends Object,
  K2 extends Object,
  K3 extends Object,
  K4 extends Object,
  V
> {
  final TwoKeyMap<K1, K2, TwoKeyMap<K3, K4, V>> _data =
      TwoKeyMap<K1, K2, TwoKeyMap<K3, K4, V>>();

  /// Stores [value] at the four-key address.
  void set(K1 first, K2 second, K3 third, K4 fourth, V value) {
    var nested = _data.get(first, second);
    if (nested == null) {
      nested = TwoKeyMap<K3, K4, V>();
      _data.set(first, second, nested);
    }
    nested.set(third, fourth, value);
  }

  /// Looks up the value at the four-key address.
  V? get(K1 first, K2 second, K3 third, K4 fourth) =>
      _data.get(first, second)?.get(third, fourth);

  /// Removes all entries.
  void clear() => _data.clear();
}
