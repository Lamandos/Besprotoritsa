// This conditional adapter is intentionally the small web-only fallback.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:besprotoritsa_app/src/content/review_status_store_api.dart';

const _storageKey = 'besprotoritsa.content.review_status';

/// Browser fallback for the same review workflow when a file is unavailable.
final class WebReviewStatusStore implements ReviewStatusStore {
  @override
  Future<Set<String>> reviewedIds() async {
    final document = _readDocument();
    final reviews = document['reviews'];
    if (reviews is! Map<String, dynamic>) return <String>{};
    return reviews.keys.toSet();
  }

  @override
  Future<void> markHumanReviewed(String contentId) async {
    final document = _readDocument();
    final reviews = Map<String, dynamic>.from(
      document['reviews'] is Map<String, dynamic>
          ? document['reviews'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
    reviews[contentId] = <String, String>{
      'status': 'human-reviewed',
      'reviewedAt': DateTime.now().toUtc().toIso8601String(),
    };
    document['reviews'] = reviews;
    html.window.localStorage[_storageKey] = jsonEncode(document);
  }

  Map<String, dynamic> _readDocument() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null) {
      return <String, dynamic>{
        'schemaVersion': 1,
        'reviews': <String, dynamic>{},
      };
    }
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }
}

/// Creates the browser-backed status store.
ReviewStatusStore createReviewStatusStore() => WebReviewStatusStore();
