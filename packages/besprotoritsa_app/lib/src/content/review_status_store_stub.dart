import 'package:besprotoritsa_app/src/content/review_status_store_api.dart';

/// Creates a portable in-memory fallback when no platform persistence exists.
ReviewStatusStore createReviewStatusStore() => MemoryReviewStatusStore();
