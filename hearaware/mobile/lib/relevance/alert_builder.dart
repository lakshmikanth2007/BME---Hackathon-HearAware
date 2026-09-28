import '../models/awareness_event.dart';
import '../models/detection.dart';

/// Turns a relevant event into the words/labels the user receives.
class AlertBuilder {
  static String _phrase(AwarenessEvent e) {
    if (!e.directionReliable) return '';
    switch (e.direction) {
      case 'left':
        return 'on your left';
      case 'right':
        return 'on your right';
      case 'front':
        return 'ahead';
      case 'behind':
        return 'behind you';
    }
    return '';
  }

  /// Events where "where?" matters. For these, an unreliable direction is stated honestly.
  static const _directional = {'horn', 'siren', 'vehicle horn', 'vehicle siren'};

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static Alert build(AwarenessEvent e, Priority priority, {bool isDemo = false}) {
    final phrase = _phrase(e);
    final isVehicle = {'car', 'bus', 'truck', 'motorcycle', 'bicycle'}.contains(e.event);
    String title;
    String spoken;

    if (e.event == 'speech') {
      final text = (e.speechText ?? '').trim();
      title = 'SOMEONE IS SPEAKING';
      spoken = text.isEmpty ? 'Someone is speaking.' : 'Someone says: $text';
    } else if (isVehicle) {
      final name = _cap(e.event);
      if (e.approaching) {
        title = '${e.event.toUpperCase()} APPROACHING';
        spoken = '$name approaching${phrase.isEmpty ? '' : ' $phrase'}.';
      } else {
        title = e.event.toUpperCase();
        spoken = '$name${phrase.isEmpty ? '' : ' $phrase'}.';
      }
    } else if (_directional.contains(e.event)) {
      title = e.event.toUpperCase();
      final base = _cap(e.event);
      if (phrase.isNotEmpty) {
        spoken = '$base $phrase.';
      } else {
        // A lone (unfused) horn/siren has no vehicle confirmation, so say "detected".
        spoken = e.source == 'fusion' ? '$base. Direction uncertain.' : '$base detected. Direction uncertain.';
      }
    } else if (e.event == 'alarm') {
      title = 'ALARM';
      spoken = 'Alarm detected.';
    } else {
      title = e.event.toUpperCase();
      final base = _cap(e.event);
      final vision = e.source == 'vision' || e.source == 'fusion';
      spoken = vision ? '$base${phrase.isEmpty ? '' : ' $phrase'}.' : '$base detected.';
    }

    return Alert(
      id: e.id,
      title: title,
      spokenText: spoken,
      eventKey: e.event,
      direction: e.direction,
      directionReliable: e.directionReliable,
      priority: priority,
      timestamp: e.timestamp,
      speechText: e.speechText,
      isDemo: isDemo,
      sources: e.source == 'fusion' ? const ['camera', 'microphone'] : [e.source == 'vision' ? 'camera' : 'microphone'],
    );
  }
}
