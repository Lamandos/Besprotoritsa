import 'dart:async';
import 'dart:collection';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/foundation.dart';

/// Plays rules events one at a time so visual effects cannot overlap.
class EventQueue extends ChangeNotifier {
  /// Creates an animation event queue.
  EventQueue({this.eventDuration = const Duration(milliseconds: 260)});

  /// Duration for one semantic animation event.
  final Duration eventDuration;
  final Queue<GameEvent> _waiting = Queue<GameEvent>();
  final List<GameEvent> _history = <GameEvent>[];
  Timer? _timer;
  GameEvent? _current;

  /// The event currently presented to the UI.
  GameEvent? get current => _current;

  /// Events that have begun playing in this game session.
  List<GameEvent> get history => List.unmodifiable(_history);

  /// True while an event is visible or more events await their turn.
  bool get isPlaying => _current != null || _waiting.isNotEmpty;

  /// Includes the visible event, which makes it useful for status UI and tests.
  int get pendingCount => _waiting.length + (_current == null ? 0 : 1);

  /// Adds a complete rules transition to the animation pipeline.
  void enqueue(Iterable<GameEvent> events) {
    _waiting.addAll(events);
    _startNext();
  }

  void _startNext() {
    if (_current != null) return;
    if (_waiting.isEmpty) {
      notifyListeners();
      return;
    }
    _current = _waiting.removeFirst();
    _history.add(_current!);
    notifyListeners();
    _timer = Timer(eventDuration, _finishCurrent);
  }

  void _finishCurrent() {
    _current = null;
    _timer = null;
    _startNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
