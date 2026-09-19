/// Persistent status storage used by the content review screen.
abstract interface class ReviewStatusStore {
  /// Returns ids that were marked as reviewed by a human.
  Future<Set<String>> reviewedIds();

  /// Persists the human review marker for [contentId].
  Future<void> markHumanReviewed(String contentId);
}

/// An in-memory store for widget tests and embedders.
final class MemoryReviewStatusStore implements ReviewStatusStore {
  final Set<String> _reviewed = <String>{};

  @override
  Future<Set<String>> reviewedIds() async => Set<String>.of(_reviewed);

  @override
  Future<void> markHumanReviewed(String contentId) async {
    _reviewed.add(contentId);
  }
}
