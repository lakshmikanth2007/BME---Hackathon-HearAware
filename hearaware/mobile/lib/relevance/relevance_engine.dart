import '../models/awareness_event.dart';
import '../models/detection.dart';
import '../models/user_profile.dart';

/// Deterministic relevance rules: decides whether an event is worth interrupting the user for.
/// Modular on purpose: an LLM-based scorer can implement the same `evaluate` signature later.
class RelevanceEngine {
  RelevanceEngine({
    DateTime Function()? clock,
    this.highCooldown = const Duration(seconds: 4),
    this.mediumCooldown = const Duration(seconds: 10),
    this.speechCooldown = const Duration(seconds: 15),
    this.minGap = const Duration(seconds: 2),
    this.coverWindow = const Duration(seconds: 6),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration highCooldown, mediumCooldown, speechCooldown, minGap, coverWindow;

  static const highEvents = {'alarm', 'siren', 'horn', 'vehicle horn', 'vehicle siren'};
  static const vehicles = {'car', 'bus', 'truck', 'motorcycle', 'bicycle'};
  static const mediumEvents = {'person', 'doorbell', 'knock', 'speech', 'dog bark', 'traffic light', 'stop sign'};
  static const _minConfidence = {
    Priority.high: 0.35, // audio classifiers rarely output very high scores
    Priority.medium: 0.55,
  };
  static const _confidenceOverride = {'speech': 0.4, 'doorbell': 0.4, 'knock': 0.4, 'dog bark': 0.4};

  final Map<String, DateTime> _lastByKey = {};
  DateTime? _lastMedium;
  DateTime? _lastHigh;

  static Priority classify(AwarenessEvent e) {
    if (highEvents.contains(e.event)) return Priority.high;
    if (vehicles.contains(e.event)) {
      return (e.approaching && e.confidence >= 0.6) ? Priority.high : Priority.medium;
    }
    if (mediumEvents.contains(e.event)) return Priority.medium;
    return Priority.low; // chairs, bottles, laptops, phones, ...
  }

  RelevanceDecision evaluate(AwarenessEvent e, UserProfile profile) {
    final now = _clock();
    final p = classify(e);
    final weight = p == Priority.high ? 100.0 : (p == Priority.medium ? 50.0 : 10.0);
    final score = weight * e.confidence;
    RelevanceDecision no(String why) => RelevanceDecision(false, p, score, why);

    if (p == Priority.low) return no('low priority');

    final minConf = _confidenceOverride[e.event] ?? _minConfidence[p]!;
    if (e.confidence < minConf) return no('low confidence');

    // Profile filtering: a Deaf user can already see what the camera sees; sounds are what they are missing.
    if (profile == UserProfile.deaf && p == Priority.medium && e.source == 'vision') {
      return no('visible to user');
    }

    // Don't pile visual chatter on top of an alert that was just delivered.
    if (p == Priority.medium && e.source == 'vision' && _lastHigh != null && now.difference(_lastHigh!) < coverWindow) {
      return no('covered by recent alert');
    }

    final key = e.event == 'speech' ? 'speech|${(e.speechText ?? '').trim().toLowerCase()}' : e.event;
    final cooldown = e.event == 'speech' ? speechCooldown : (p == Priority.high ? highCooldown : mediumCooldown);
    final last = _lastByKey[key];
    if (last != null && now.difference(last) < cooldown) return no('duplicate / cooldown');

    if (p == Priority.medium && _lastMedium != null && now.difference(_lastMedium!) < minGap) {
      return no('rate limited');
    }

    _lastByKey[key] = now;
    if (p == Priority.medium) _lastMedium = now;
    if (p == Priority.high) _lastHigh = now;
    return RelevanceDecision(true, p, score, 'deliver');
  }

  void reset() {
    _lastByKey.clear();
    _lastMedium = null;
    _lastHigh = null;
  }
}
