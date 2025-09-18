/// Filesystem safety utilities for group keys according to GROUP-INDEXING.md specification.
library;

import 'dart:convert';

/// Ensures group keys are safe for use as filesystem path components across all platforms.
///
/// This utility implements the filesystem safety specification from GROUP-INDEXING.md,
/// providing automatic conversion of unsafe group keys to deterministic, collision-resistant
/// hash-based alternatives while preserving human-readable keys when possible.
class FilesystemSafety {
  // Conservative whitelist pattern - works on all platforms
  static final RegExp _safePattern = RegExp(r'^[a-zA-Z0-9._-]+$');

  // Maximum length for preserved human-readable keys
  static const int _maxSafeLength = 50;

  /// Makes a group key safe for filesystem use according to the specification.
  ///
  /// **Safe Key Preservation:** Keys meeting all criteria are preserved unchanged:
  /// - Character whitelist: Only [a-zA-Z0-9._-] characters
  /// - Length limit: 50 characters or fewer
  /// - Name safety: Not '.', '..', or hidden (starting with '.')
  ///
  /// **Hash-Based Fallback:** Unsafe keys are converted to format:
  /// `{originalLength}_{16-char-hex-hash}` using xxHash64
  ///
  /// Examples:
  /// ```dart
  /// makeFilesystemSafe("work") → "work"                    // Safe, preserved
  /// makeFilesystemSafe("contains/slash") → "14_a1b2c3d4e5f67890"  // Hashed
  /// makeFilesystemSafe("very-long-name...") → "52_9876543210abcdef" // Too long, hashed
  /// ```
  static String makeFilesystemSafe(String groupKey) {
    if (_isSafe(groupKey)) {
      return groupKey;
    }

    // Generate hash with character count prefix
    final hash = _xxHash64(groupKey);
    // Ensure positive representation for hex string
    final positiveHash = hash < 0 ? -hash : hash;
    final hexHash = positiveHash.toRadixString(16).padLeft(16, '0');
    return '${groupKey.length}_$hexHash';
  }

  /// Checks if a group key is safe for direct filesystem use.
  ///
  /// Returns true if the key meets all safety criteria:
  /// - Matches character whitelist [a-zA-Z0-9._-]
  /// - Length is 50 characters or fewer
  /// - Not a reserved name ('.', '..')
  /// - Does not start with '.' (hidden file)
  static bool _isSafe(String groupKey) {
    // Check basic patterns
    if (groupKey.isEmpty ||
        groupKey.length > _maxSafeLength ||
        !_safePattern.hasMatch(groupKey)) {
      return false;
    }

    // Check for reserved directory navigation names
    if (groupKey == '.' || groupKey == '..') {
      return false;
    }

    // Check for hidden files (starting with '.')
    if (groupKey.startsWith('.')) {
      return false;
    }

    return true;
  }

  /// Computes xxHash64 for the given input string.
  ///
  /// Uses xxHash64 algorithm consistent with the framework's sharding and
  /// clock hashing as specified in SHARDING.md and CRDT-SPECIFICATION.md.
  ///
  /// This implementation uses a simple but effective hash function suitable
  /// for group key generation. For production use, consider using a dedicated
  /// xxHash library for optimal performance.
  static int _xxHash64(String input) {
    final bytes = utf8.encode(input);
    return _xxHash64Bytes(bytes);
  }

  /// xxHash64 implementation for byte data.
  ///
  /// This is a simplified implementation of xxHash64 that provides good
  /// distribution and collision resistance for group key generation.
  /// The algorithm follows the xxHash64 specification for deterministic results.
  static int _xxHash64Bytes(List<int> data) {
    // Use class constants
    const int prime1 = _prime1;
    const int prime2 = _prime2;
    const int prime3 = _prime3;
    const int prime4 = _prime4;
    const int prime5 = _prime5;

    final int seed = 0; // Using 0 as seed for deterministic results
    final int len = data.length;

    int h64;

    if (len >= 32) {
      int v1 = _addUint64(seed, prime1, prime2);
      int v2 = _addUint64(seed, prime2);
      int v3 = seed;
      int v4 = _subUint64(seed, prime1);

      // Process 32-byte chunks
      int i = 0;
      while (i <= len - 32) {
        v1 = _round(v1, _readLittleEndian64(data, i));
        v2 = _round(v2, _readLittleEndian64(data, i + 8));
        v3 = _round(v3, _readLittleEndian64(data, i + 16));
        v4 = _round(v4, _readLittleEndian64(data, i + 24));
        i += 32;
      }

      h64 = _rotateLeft(_addUint64(v1, 1), 1) +
            _rotateLeft(_addUint64(v2, 7), 7) +
            _rotateLeft(_addUint64(v3, 12), 12) +
            _rotateLeft(_addUint64(v4, 18), 18);

      h64 = _mergeRound(h64, v1);
      h64 = _mergeRound(h64, v2);
      h64 = _mergeRound(h64, v3);
      h64 = _mergeRound(h64, v4);
    } else {
      h64 = _addUint64(seed, prime5);
    }

    h64 = _addUint64(h64, len);

    // Process remaining bytes
    int remaining = len;
    if (len >= 32) {
      remaining = len % 32;
    }

    int offset = len - remaining;

    while (remaining >= 8) {
      final int k1 = _readLittleEndian64(data, offset);
      h64 ^= _round(0, k1);
      h64 = _rotateLeft(h64, 27) * prime1 + prime4;
      offset += 8;
      remaining -= 8;
    }

    while (remaining >= 4) {
      final int k1 = _readLittleEndian32(data, offset);
      h64 ^= k1 * prime1;
      h64 = _rotateLeft(h64, 23) * prime2 + prime3;
      offset += 4;
      remaining -= 4;
    }

    while (remaining > 0) {
      final int k1 = data[offset] & 0xFF;
      h64 ^= k1 * prime5;
      h64 = _rotateLeft(h64, 11) * prime1;
      offset += 1;
      remaining -= 1;
    }

    // Final mix
    h64 ^= h64 >>> 33;
    h64 = _mulUint64(h64, prime2);
    h64 ^= h64 >>> 29;
    h64 = _mulUint64(h64, prime3);
    h64 ^= h64 >>> 32;

    return h64;
  }

  // Helper methods for xxHash64 implementation

  static int _round(int acc, int input) {
    acc = _addUint64(acc, _mulUint64(input, _prime2));
    acc = _rotateLeft(acc, 31);
    return _mulUint64(acc, _prime1);
  }

  static int _mergeRound(int acc, int val) {
    val = _round(0, val);
    acc ^= val;
    acc = _addUint64(_mulUint64(acc, _prime1), _prime4);
    return acc;
  }

  static int _rotateLeft(int value, int amount) {
    return ((value << amount) | (value >>> (64 - amount))) & 0xFFFFFFFFFFFFFFFF;
  }

  static int _addUint64(int a, int b, [int c = 0]) {
    return (a + b + c) & 0xFFFFFFFFFFFFFFFF;
  }

  static int _subUint64(int a, int b) {
    return (a - b) & 0xFFFFFFFFFFFFFFFF;
  }

  static int _mulUint64(int a, int b) {
    return (a * b) & 0xFFFFFFFFFFFFFFFF;
  }

  static int _readLittleEndian64(List<int> data, int offset) {
    return (data[offset] & 0xFF) |
           ((data[offset + 1] & 0xFF) << 8) |
           ((data[offset + 2] & 0xFF) << 16) |
           ((data[offset + 3] & 0xFF) << 24) |
           ((data[offset + 4] & 0xFF) << 32) |
           ((data[offset + 5] & 0xFF) << 40) |
           ((data[offset + 6] & 0xFF) << 48) |
           ((data[offset + 7] & 0xFF) << 56);
  }

  static int _readLittleEndian32(List<int> data, int offset) {
    return (data[offset] & 0xFF) |
           ((data[offset + 1] & 0xFF) << 8) |
           ((data[offset + 2] & 0xFF) << 16) |
           ((data[offset + 3] & 0xFF) << 24);
  }

  // xxHash64 constants
  static const int _prime1 = 0x9E3779B185EBCA87;
  static const int _prime2 = 0xC2B2AE3D27D4EB4F;
  static const int _prime3 = 0x165667B19E3779F9;
  static const int _prime4 = 0x85EBCA77C2B2AE63;
  static const int _prime5 = 0x27D4EB2F165667C5;
}