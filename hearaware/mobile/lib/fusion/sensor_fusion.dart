import '../models/awareness_event.dart';

class _Seen {
  _Seen(this.event, this.at);
  final AwarenessEvent event;
  final DateTime at;
  bool consumed = false;
}

/// Combines camera + microphone events into one more useful event.
///
///   vision: car (left) + audio: horn  ->  fusion: "vehicle horn" (left)
///
/// Rules are deterministic and time-windowed. Direction is never invented: the vision direction is used when
/// reliable, else the audio direction when reliable, else 'unknown'.
class SensorFusion {
  SensorFusion({
    this.window = const Duration(milliseconds: 2500),
    this.hold = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration window; // how long a sighting can be paired with a sound
  final Duration hold; // how long a lone horn/siren waits for a matching vehicle sighting
  final DateTime Function() _clock;

  static const vehicleClasses = {'car', 'bus', 'truck', 'motorcycle', 'bicycle'};
  static const hornLike = {'horn', 'siren'};

  final List<_Seen> _recentVehicles = [];
  final List<_Seen> _pendingSounds = [];
  final List<_Seen> _heldVision = [];

  bool get hasPending => _pendingSounds.isNotEmpty || _heldVision.any((s) => !s.consumed);

  void reset() {
    _recentVehicles.clear();
    _pendingSounds.clear();
    _heldVision.clear();
  }

  /// Feed one event; returns the events to forward to the relevance engine right now.
  List<AwarenessEvent> process(AwarenessEvent e) {
    final now = _clock();
    _recentVehicles.removeWhere((s) => now.difference(s.at) > window);

    if (e.source == 'audio' && hornLike.contains(e.event)) {
      final v = _bestVehicle();
      if (v != null) {
        v.consumed = true;
        return [_fuse(e, v.event)];
      }
      _pendingSounds.add(_Seen(e, now)); // wait briefly for the camera to confirm
      return const [];
    }

    if (e.source == 'vision' && vehicleClasses.contains(e.event)) {
      final seen = _Seen(e, now);
      _recentVehicles.add(seen);
      final pendingIdx = _pendingSounds.indexWhere((p) => now.difference(p.at) <= window);
      if (pendingIdx >= 0) {
        final sound = _pendingSounds.removeAt(pendingIdx);
        seen.consumed = true;
        return [_fuse(sound.event, e)];
      }
      if (e.approaching) return [e]; // urgent: never delay an approaching vehicle
      // Hold a plain sighting for a moment: if a horn/siren arrives, ONE fused alert replaces two separate ones.
      _heldVision.add(seen);
      return const [];
    }
    return [e];
  }

  /// Release lone sounds / sightings whose hold time has elapsed (nothing confirmed them).
  List<AwarenessEvent> flush({bool force = false}) {
    final now = _clock();
    final out = <AwarenessEvent>[];
    _pendingSounds.removeWhere((p) {
      final expired = force || now.difference(p.at) >= hold;
      if (expired) out.add(p.event);
      return expired;
    });
    _heldVision.removeWhere((v) {
      final expired = force || now.difference(v.at) >= hold;
      if (expired && !v.consumed && !force) out.add(v.event);
      return expired;
    });
    return out;
  }

  _Seen? _bestVehicle() {
    _Seen? best;
    for (final s in _recentVehicles) {
      if (s.consumed) continue;
      if (best == null || s.event.confidence > best.event.confidence) best = s;
    }
    return best;
  }

  AwarenessEvent _fuse(AwarenessEvent sound, AwarenessEvent vision) {
    String dir = 'unknown';
    double dirConf = 0;
    if (vision.directionReliable) {
      dir = vision.direction;
      dirConf = vision.directionConfidence;
    } else if (sound.directionReliable) {
      dir = sound.direction;
      dirConf = sound.directionConfidence;
    }
    final name = 'vehicle ${sound.event}';
    return AwarenessEvent.create(
      source: 'fusion',
      event: name,
      description: '${name[0].toUpperCase()}${name.substring(1)}',
      confidence: (sound.confidence + vision.confidence) / 2,
      direction: dir,
      directionConfidence: dirConf,
      approaching: vision.approaching,
      at: _clock(),
    );
  }
}
