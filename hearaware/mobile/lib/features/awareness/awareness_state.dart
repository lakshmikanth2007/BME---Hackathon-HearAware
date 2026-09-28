import '../../models/detection.dart';
import '../../models/user_profile.dart';

class AwarenessViewState {
  const AwarenessViewState({
    this.status = AwarenessStatus.idle,
    this.mode = AwarenessMode.real,
    this.profile,
    this.latest,
    this.activeAlert,
    this.history = const [],
    this.suppressed = 0,
    this.camera = SensorStatus.off,
    this.microphone = SensorStatus.off,
    this.message,
    this.models = const {},
  });

  final AwarenessStatus status;
  final AwarenessMode mode;
  final UserProfile? profile;
  final Alert? latest;
  final Alert? activeAlert; // visual alert on screen (Deaf profile)
  final List<Alert> history;
  final int suppressed; // background events the relevance engine filtered out
  final SensorStatus camera;
  final SensorStatus microphone;
  final String? message; // user-facing problem / hint
  final Map<String, String> models;

  bool get running =>
      status != AwarenessStatus.idle && status != AwarenessStatus.error && status != AwarenessStatus.permissionDenied;

  AwarenessViewState copyWith({
    AwarenessStatus? status,
    AwarenessMode? mode,
    UserProfile? profile,
    Alert? latest,
    Alert? activeAlert,
    bool clearActive = false,
    List<Alert>? history,
    int? suppressed,
    SensorStatus? camera,
    SensorStatus? microphone,
    String? message,
    bool clearMessage = false,
    Map<String, String>? models,
  }) =>
      AwarenessViewState(
        status: status ?? this.status,
        mode: mode ?? this.mode,
        profile: profile ?? this.profile,
        latest: latest ?? this.latest,
        activeAlert: clearActive ? null : (activeAlert ?? this.activeAlert),
        history: history ?? this.history,
        suppressed: suppressed ?? this.suppressed,
        camera: camera ?? this.camera,
        microphone: microphone ?? this.microphone,
        message: clearMessage ? null : (message ?? this.message),
        models: models ?? this.models,
      );

  static String statusLabel(AwarenessStatus s) {
    switch (s) {
      case AwarenessStatus.idle:
        return 'Ready';
      case AwarenessStatus.initializing:
        return 'Starting...';
      case AwarenessStatus.active:
        return 'Awareness active';
      case AwarenessStatus.processing:
        return 'Processing';
      case AwarenessStatus.eventDetected:
        return 'Event detected';
      case AwarenessStatus.alertDelivered:
        return 'Alert delivered';
      case AwarenessStatus.paused:
        return 'Paused';
      case AwarenessStatus.error:
        return 'Problem';
      case AwarenessStatus.permissionDenied:
        return 'Permission needed';
    }
  }
}
