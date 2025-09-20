/// CRDT type definitions from the architecture specification.
///
/// Defines the state-based CRDT algorithms used for property-level
/// merge strategies as outlined in the crdt-algorithms vocabulary.

/// Base interface for all CRDT types.
abstract interface class CrdtType<T> {
  /// Merge this CRDT with another CRDT of the same type.
  T merge(T other);

  /// Get the current value of this CRDT.
  dynamic get value;
}

/// Last-Writer-Wins Register for single-value properties.
/// Uses Hybrid Logical Clock for conflict resolution.
class LwwRegister<T> implements CrdtType<LwwRegister<T>> {
  final T _value;
  final DateTime _timestamp;
  final String _installationId;

  const LwwRegister(this._value, this._timestamp, this._installationId);

  @override
  T get value => _value;

  DateTime get timestamp => _timestamp;
  String get installationId => _installationId;

  @override
  LwwRegister<T> merge(LwwRegister<T> other) {
    // Compare timestamps, use installation ID as tiebreaker
    if (_timestamp.isAfter(other._timestamp)) {
      return this;
    } else if (other._timestamp.isAfter(_timestamp)) {
      return other;
    } else {
      // Timestamp tie - use installation ID lexicographic comparison
      return _installationId.compareTo(other._installationId) > 0
          ? this
          : other;
    }
  }
}

/// First-Writer-Wins Register for immutable properties.
class FwwRegister<T> implements CrdtType<FwwRegister<T>> {
  final T _value;
  final DateTime _timestamp;
  final String _installationId;

  const FwwRegister(this._value, this._timestamp, this._installationId);

  @override
  T get value => _value;

  DateTime get timestamp => _timestamp;
  String get installationId => _installationId;

  @override
  FwwRegister<T> merge(FwwRegister<T> other) {
    // Always keep the earlier timestamp (first writer wins)
    if (_timestamp.isBefore(other._timestamp)) {
      return this;
    } else if (other._timestamp.isBefore(_timestamp)) {
      return other;
    } else {
      // Timestamp tie - use installation ID lexicographic comparison (smaller wins)
      return _installationId.compareTo(other._installationId) < 0
          ? this
          : other;
    }
  }
}

/// Observed-Remove Set for multi-value properties.
class OrSet<T> implements CrdtType<OrSet<T>> {
  final Set<T> _elements;
  final Set<String> _tombstones;

  const OrSet(this._elements, this._tombstones);

  @override
  Set<T> get value => _elements.difference(_tombstones.cast<T>());

  Set<T> get elements => Set.from(_elements);
  Set<String> get tombstones => Set.from(_tombstones);

  @override
  OrSet<T> merge(OrSet<T> other) {
    return OrSet<T>(
      _elements.union(other._elements),
      _tombstones.union(other._tombstones),
    );
  }

  /// Add an element to the set.
  OrSet<T> add(T element) {
    return OrSet<T>(_elements.union({element}), _tombstones);
  }

  /// Remove an element from the set (adds to tombstones).
  OrSet<T> remove(T element) {
    return OrSet<T>(_elements, _tombstones.union({element.toString()}));
  }
}
