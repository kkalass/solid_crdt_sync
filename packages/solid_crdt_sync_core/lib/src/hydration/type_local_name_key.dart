/// Key for identifying items by type and local name.
library;

/// Key composed of a Dart Type and local name string.
///
/// Used to uniquely identify hydration streams, converters, and other
/// components that are keyed by (Type, localName) pairs.
class TypeLocalNameKey {
  final Type type;
  final String localName;

  const TypeLocalNameKey(this.type, this.localName);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TypeLocalNameKey &&
        other.type == type &&
        other.localName == localName;
  }

  @override
  int get hashCode => Object.hash(type, localName);

  @override
  String toString() => 'TypeLocalNameKey($type, $localName)';
}