import 'awareness_event.dart';

enum Priority { high, medium, low }

/// App-level state machine (spec section 15).
enum AwarenessStatus { idle, initializing, active, processing, eventDetected, alertDelivered, paused, error, permissionDenied }

enum SensorStatus { off, on, denied, unavailable }

/// What the user actually receives: the output of fusion + relevance, ready for TTS or a visual alert.
class Alert {
  Alert({
    required this.id,
    required this.title,
    required this.spokenText,
    required this.eventKey,
    required this.direction,
    required this.directionReliable,
    required this.priority,
    required this.timestamp,
    this.speechText,
    this.isDemo = false,
    this.sources = const [],
  });

  final String id;
  final String title; // e.g. "VEHICLE HORN" (visual alerts)
  final String spokenText; // e.g. "Vehicle horn on your left." (TTS)
  final String eventKey;
  final String direction;
  final bool directionReliable;
  final Priority priority;
  final DateTime timestamp;
  final String? speechText;
  final bool isDemo;
  final List<String> sources;

  /// Direction text for visual alerts. Never invents a direction.
  String? get directionLabel {
    if (!directionReliable) return null;
    switch (direction) {
      case 'left':
        return 'LEFT';
      case 'right':
        return 'RIGHT';
      case 'front':
        return 'AHEAD';
      case 'behind':
        return 'BEHIND';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'spoken': spokenText,
        'event': eventKey,
        'direction': direction,
        'direction_reliable': directionReliable,
        'priority': priority.name,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'speech_text': speechText,
        'demo': isDemo,
        'sources': sources,
      };

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        id: j['id'].toString(),
        title: (j['title'] ?? '').toString(),
        spokenText: (j['spoken'] ?? '').toString(),
        eventKey: (j['event'] ?? '').toString(),
        direction: (j['direction'] ?? 'unknown').toString(),
        directionReliable: j['direction_reliable'] == true,
        priority: Priority.values.firstWhere((p) => p.name == j['priority'], orElse: () => Priority.medium),
        timestamp: DateTime.tryParse((j['timestamp'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        speechText: j['speech_text'] as String?,
        isDemo: j['demo'] == true,
        sources: ((j['sources'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// Result of the relevance engine for one event.
class RelevanceDecision {
  const RelevanceDecision(this.deliver, this.priority, this.score, this.reason);
  final bool deliver;
  final Priority priority;
  final double score;
  final String reason;
}

extension EventKinds on AwarenessEvent {
  bool get isSound => source == 'audio';
}
