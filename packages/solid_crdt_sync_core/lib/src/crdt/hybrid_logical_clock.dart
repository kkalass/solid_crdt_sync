/// Hybrid Logical Clock implementation for CRDT versioning.
/// 
/// Provides distributed timestamp generation for conflict resolution
/// as specified in the CRDT mechanics vocabulary.

/// Hybrid Logical Clock for distributed timestamp generation.
class HybridLogicalClock {
  int _logicalTime;
  final String _installationId;
  DateTime _lastWallTime;
  
  HybridLogicalClock(this._installationId) 
      : _logicalTime = 0, 
        _lastWallTime = DateTime.now();
  
  String get installationId => _installationId;
  
  /// Generate a new timestamp.
  HlcTimestamp tick() {
    final wallTime = DateTime.now();
    
    if (wallTime.isAfter(_lastWallTime)) {
      _lastWallTime = wallTime;
      _logicalTime = 0;
    } else {
      _logicalTime++;
    }
    
    return HlcTimestamp(
      wallTime: _lastWallTime,
      logicalTime: _logicalTime,
      installationId: _installationId,
    );
  }
  
  /// Update clock based on received timestamp.
  HlcTimestamp receive(HlcTimestamp other) {
    final wallTime = DateTime.now();
    final maxWallTime = wallTime.isAfter(other.wallTime) 
        ? wallTime 
        : other.wallTime;
    
    if (maxWallTime == _lastWallTime) {
      _logicalTime = (_logicalTime > other.logicalTime) 
          ? _logicalTime + 1 
          : other.logicalTime + 1;
    } else {
      _lastWallTime = maxWallTime;
      _logicalTime = maxWallTime == wallTime ? 0 : other.logicalTime + 1;
    }
    
    return HlcTimestamp(
      wallTime: _lastWallTime,
      logicalTime: _logicalTime, 
      installationId: _installationId,
    );
  }
}

/// A timestamp from a Hybrid Logical Clock.
class HlcTimestamp implements Comparable<HlcTimestamp> {
  final DateTime wallTime;
  final int logicalTime;
  final String installationId;
  
  const HlcTimestamp({
    required this.wallTime,
    required this.logicalTime,
    required this.installationId,
  });
  
  @override
  int compareTo(HlcTimestamp other) {
    // Compare wall time first
    final wallTimeComparison = wallTime.compareTo(other.wallTime);
    if (wallTimeComparison != 0) return wallTimeComparison;
    
    // Then logical time
    final logicalTimeComparison = logicalTime.compareTo(other.logicalTime);
    if (logicalTimeComparison != 0) return logicalTimeComparison;
    
    // Finally installation ID as tiebreaker
    return installationId.compareTo(other.installationId);
  }
  
  @override
  bool operator ==(Object other) {
    return other is HlcTimestamp &&
        wallTime == other.wallTime &&
        logicalTime == other.logicalTime &&
        installationId == other.installationId;
  }
  
  @override
  int get hashCode => Object.hash(wallTime, logicalTime, installationId);
  
  @override
  String toString() => 'HLC($wallTime,$logicalTime,$installationId)';
}