/// Normalized event produced by every perception model (vision / audio / speech) and by fusion.
class AwarenessEvent {
  AwarenessEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.event,
    required this.description,
    required double confidence,
    String direction = 'unknown',
    double directionConfidence = 0,
    this.speechText,
    this.approaching = false,
  })  : confidence = confidence.clamp(0.0, 1.0).toDouble(),
        direction = validDirections.contains(direction) ? direction : 'unknown',
        directionConfidence = validDirections.contains(direction) && direction != 'unknown'
            ? directionConfidence.clamp(0.0, 1.0).toDouble()
            : 0.0;

  static const validDirections = {'left', 'right', 'front', 'behind', 'unknown'};
  static const reliableDirectionThreshold = 0.5;
  static int _seq = 0;

  factory AwarenessEvent.create({
    required String source,
    required String event,
    String? description,
    required double confidence,
    String direction = 'unknown',
    double directionConfidence = 0,
    String? speechText,
    bool approaching = false,
    DateTime? at,
  }) {
    _seq++;
    final t = at ?? DateTime.now();
    return AwarenessEvent(
      id: 'e${t.microsecondsSinceEpoch}_$_seq',
      timestamp: t,
      source: source,
      event: event,
      description: description ?? event,
      confidence: confidence,
      direction: direction,
      directionConfidence: directionConfidence,
      speechText: speechText,
      approaching: approaching,
    );
  }

  factory AwarenessEvent.fromJson(Map<String, dynamic> j) => AwarenessEvent(
        id: (j['id'] ?? 'e${DateTime.now().microsecondsSinceEpoch}').toString(),
        timestamp: DateTime.tryParse((j['timestamp'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        source: (j['source'] ?? 'vision').toString(),
        event: (j['event'] ?? 'unknown').toString(),
        description: (j['description'] ?? j['event'] ?? '').toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        direction: (j['direction'] ?? 'unknown').toString(),
        directionConfidence: (j['direction_confidence'] as num?)?.toDouble() ?? 0,
        speechText: j['speech_text'] as String?,
        approaching: j['approaching'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'source': source,
        'event': event,
        'description': description,
        'confidence': confidence,
        'direction': direction,
        'direction_confidence': directionConfidence,
        'speech_text': speechText,
        'approaching': approaching,
      };

  final String id;
  final DateTime timestamp;
  final String source; // vision | audio | speech | fusion
  final String event;
  final String description;
  final double confidence; // event confidence (model score, not a guaranteed probability)
  final String direction; // left | right | front | behind | unknown
  final double directionConfidence; // kept separate from event confidence
  final String? speechText;
  final bool approaching;

  bool get directionReliable => direction != 'unknown' && directionConfidence >= reliableDirectionThreshold;
}
