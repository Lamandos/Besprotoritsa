import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_app/src/content/review_status_store_api.dart';

/// File-backed review statuses for internal desktop/dev builds.
final class FileReviewStatusStore implements ReviewStatusStore {
  /// Creates a store writing the repository-relative review status file.
  FileReviewStatusStore({this.path = 'content/review_status.json'});

  /// Path to the status JSON file.
  final String path;

  @override
  Future<Set<String>> reviewedIds() async {
    final file = File(path);
    // The store is only used by the internal dev menu; keep the UI async.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) return <String>{};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return <String>{};
    final reviews = decoded['reviews'];
    if (reviews is! Map<String, dynamic>) return <String>{};
    return reviews.keys.toSet();
  }

  @override
  Future<void> markHumanReviewed(String contentId) async {
    final file = File(path);
    final document = await _readDocument(file);
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
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
      flush: true,
    );
  }

  Future<Map<String, dynamic>> _readDocument(File file) async {
    // The store is only used by the internal dev menu; keep the UI async.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      return <String, dynamic>{
        'schemaVersion': 1,
        'reviews': <String, dynamic>{},
      };
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'content/review_status.json must be an object.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }
}

/// Creates the default file-backed store.
ReviewStatusStore createReviewStatusStore() => FileReviewStatusStore();
