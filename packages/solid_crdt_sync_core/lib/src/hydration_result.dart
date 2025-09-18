/// Result object for hydration streams containing batched updates.
library;

/// Result object for hydration streams containing batched updates.
///
/// Represents a batch of items that have been updated, deleted, or fetched
/// during hydration operations. Includes cursor information for pagination
/// and consistency checking.
class HydrationResult<T> {
  /// Items that were added or updated
  final List<T> items;

  /// Items that were deleted
  final List<T> deletedItems;

  /// Cursor position at the start of this batch (for consistency checking)
  final String? originalCursor;

  /// Cursor position after processing this batch (for pagination)
  final String? nextCursor;

  /// Whether more items are available beyond this batch
  final bool hasMore;

  const HydrationResult({
    required this.items,
    required this.deletedItems,
    required this.originalCursor,
    required this.nextCursor,
    required this.hasMore,
  });

  @override
  String toString() {
    return 'HydrationResult('
        'items: ${items.length}, '
        'deletedItems: ${deletedItems.length}, '
        'originalCursor: $originalCursor, '
        'nextCursor: $nextCursor, '
        'hasMore: $hasMore)';
  }
}
