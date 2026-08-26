import 'dart:convert';
import 'dart:developer' show log;

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../constants/app_constants.dart';

class QueuedEvent {
  const QueuedEvent({
    required this.key,
    required this.name,
    required this.props,
    required this.createdAt,
  });

  final dynamic key;
  final String name;
  final Map<String, Object?> props;
  final DateTime createdAt;
}

/// Analytics events waiting to reach the server.
///
/// Events used to go straight to the network and were dropped whenever there
/// was no account yet — which is every event before the first save, so the
/// whole top of the funnel (`topic_selected` especially) was invisible.
/// Queueing them means they survive being offline and being signed out, and get
/// attributed to whichever account the device ends up on.
///
/// Lossy by design at the edges: the queue is capped, and the oldest go first.
/// A missing event is a rounding error; a queue that grows without limit is a
/// bug on someone's disk.
class EventQueue {
  Box<String> get _box => Hive.box<String>(AppConstants.hiveEventsBox);

  /// Auto-incrementing keys, so insertion order is drain order.
  Future<void> add(String name, Map<String, Object?> props) async {
    await _box.add(
      jsonEncode({
        'name': name,
        'props': props,
        // Stamped now rather than at flush, or a week of offline events would
        // all land with the same timestamp and every funnel would be wrong.
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    await _enforceCap();
  }

  List<QueuedEvent> pending({int limit = 200}) {
    final events = <QueuedEvent>[];
    for (final key in _box.keys) {
      if (events.length >= limit) break;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        events.add(
          QueuedEvent(
            key: key,
            name: json['name'] as String,
            props: Map<String, Object?>.from(json['props'] as Map),
            createdAt: DateTime.parse(json['created_at'] as String),
          ),
        );
      } catch (e) {
        log('EventQueue: dropping unreadable event: $e');
        _box.delete(key);
      }
    }
    return events;
  }

  Future<void> remove(Iterable<dynamic> keys) => _box.deleteAll(keys);

  bool get isEmpty => _box.isEmpty;

  int get length => _box.length;

  Future<void> _enforceCap() async {
    final excess = _box.length - AppConstants.maxQueuedEvents;
    if (excess <= 0) return;
    await _box.deleteAll(_box.keys.take(excess).toList());
    log('EventQueue: dropped $excess oldest events (over cap)');
  }
}
