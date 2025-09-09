/// CRDT merge strategy annotations for RDF properties.
library;

/// Annotation for Last-Writer-Wins Register merge strategy.
///
/// Used for single-value properties where conflicts are resolved by
/// keeping the value with the most recent timestamp.
class CrdtLwwRegister {
  const CrdtLwwRegister();
}

/// Annotation for First-Writer-Wins Register merge strategy.
///
/// Used for single-value properties that should be immutable after
/// first assignment.
class CrdtFwwRegister {
  const CrdtFwwRegister();
}

/// Annotation for Observed-Remove Set merge strategy.
///
/// Used for multi-value properties where additions and removals
/// can happen independently and merge together.
class CrdtOrSet {
  const CrdtOrSet();
}

/// Annotation for immutable properties that never change.
///
/// Used for properties like creation timestamps that should
/// remain constant once set.
class CrdtImmutable {
  const CrdtImmutable();
}
