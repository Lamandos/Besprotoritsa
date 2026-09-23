// Public wire fields are documented by the containing wire-model types.
// ignore_for_file: public_member_api_docs

/// Versioned, recipient-specific network state.
///
/// This model is intentionally separate from the deterministic rules model:
/// it contains only data the recipient was allowed to receive. Presentation
/// adapters may read it, but it must never be passed to `step` or `validate`.
final class WireGameState {
  const WireGameState({
    required this.version,
    required this.round,
    required this.phase,
    required this.isComplete,
    required this.quests,
    required this.document,
  });

  factory WireGameState.fromJson(Map<String, Object?> json) {
    final version = json['wireVersion'];
    final round = json['round'];
    final phase = json['phase'];
    final complete = json['isComplete'];
    if (version is! int || version != 1) {
      throw const FormatException('Unsupported wire state version.');
    }
    if (round is! int || phase is! String || complete is! bool) {
      throw const FormatException('Invalid wire state envelope.');
    }
    return WireGameState(
      version: version,
      round: round,
      phase: phase,
      isComplete: complete,
      quests: WireQuestState.fromJson(_object(json['quests'])),
      document: Map<String, Object?>.unmodifiable(json),
    );
  }

  final int version;
  final int round;
  final String phase;
  final bool isComplete;
  final WireQuestState quests;

  /// The allow-listed payload for the legacy presentation adapter.
  final Map<String, Object?> document;
}

final class WireQuestState {
  const WireQuestState({
    required this.story,
    required this.personal,
    required this.hiddenPersonalTaskCounts,
  });

  factory WireQuestState.fromJson(Map<String, Object?> json) => WireQuestState(
    story: _entries(json['story']),
    personal: _entries(json['personal']),
    hiddenPersonalTaskCounts: _counts(json['hiddenPersonalTaskCounts']),
  );

  final List<WireQuest> story;
  final List<WireQuest> personal;
  final Map<String, int> hiddenPersonalTaskCounts;
}

final class WireQuest {
  const WireQuest({required this.id, required this.status});

  final String id;
  final String status;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected wire object.');
  }
  return value.map((key, entry) => MapEntry(key.toString(), entry));
}

List<WireQuest> _entries(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected quest list.');
  }
  return value
      .map((entry) {
        final json = _object(entry);
        final id = json['id'];
        final status = json['status'];
        if (id is! String || status is! String) {
          throw const FormatException('Invalid quest wire entry.');
        }
        return WireQuest(id: id, status: status);
      })
      .toList(growable: false);
}

Map<String, int> _counts(Object? value) {
  final json = _object(value);
  if (json.values.any((count) => count is! int)) {
    throw const FormatException('Invalid hidden quest counts.');
  }
  return Map<String, int>.unmodifiable(json.cast<String, int>());
}
