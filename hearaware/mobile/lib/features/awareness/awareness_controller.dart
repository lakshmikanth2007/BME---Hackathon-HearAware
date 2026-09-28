import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../ai/whisper_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../fusion/sensor_fusion.dart';
import '../../models/awareness_event.dart';
import '../../models/detection.dart';
import '../../models/user_profile.dart';
import '../../relevance/alert_builder.dart';
import '../../relevance/relevance_engine.dart';
import 'awareness_state.dart';
import 'demo_scenarios.dart';

final awarenessProvider =
    NotifierProvider<AwarenessController, AwarenessViewState>(AwarenessController.new);

/// Owns the whole pipeline:  events -> SensorFusion -> RelevanceEngine -> (TTS | visual alert).
/// Real Mode and Demo Mode both enter through [ingest], so they share exactly the same logic.
class AwarenessController extends Notifier<AwarenessViewState> {
  late SensorFusion _fusion;
  late RelevanceEngine _relevance;
  bool _running = false;
  bool _sensorsOn = false;
  Timer? _flushTimer, _pulseTimer, _statusTimer, _dismissTimer;
  StreamSubscription? _evSub, _modelSub, _closedSub;
  int _demoRun = 0;

  @override
  AwarenessViewState build() {
    _fusion = SensorFusion();
    _relevance = RelevanceEngine();
    ref.onDispose(_cancelAll);
    final store = ref.read(settingsStoreProvider);
    return AwarenessViewState(profile: store.profile, history: store.loadHistory());
  }

  // ---------------------------------------------------------------- profile / mode
  Future<void> setProfile(UserProfile p) async {
    if (state.profile == p) return;
    if (_running) await stop();
    _relevance.reset();
    state = state.copyWith(profile: p, clearActive: true);
    await ref.read(settingsStoreProvider).saveProfile(p);
    unawaited(ref.read(firebaseServiceProvider).saveProfile(p));
  }

  void setMode(AwarenessMode m) {
    if (_running) return; // switching mid-session would mix live and scripted events
    state = state.copyWith(mode: m, clearMessage: true);
  }

  // ---------------------------------------------------------------- lifecycle
  Future<void> start() async {
    if (_running) return;
    _relevance.reset();
    state = state.copyWith(status: AwarenessStatus.initializing, clearMessage: true, clearActive: true);
    await ref.read(ttsServiceProvider).init(rate: ref.read(settingsProvider).speechRate);

    if (state.mode == AwarenessMode.demo) {
      _running = true;
      state = state.copyWith(status: AwarenessStatus.active, message: 'Demo Mode: scripted scenarios, same pipeline.');
      await _keepAwake(true);
      await _announce('Demo mode. Awareness active.');
      return;
    }

    // ---- Real mode: permissions
    final perms = ref.read(permissionHelperProvider);
    final cam = await perms.requestCamera();
    final mic = await perms.requestMicrophone();
    state = state.copyWith(
      camera: cam ? SensorStatus.off : SensorStatus.denied,
      microphone: mic ? SensorStatus.off : SensorStatus.denied,
    );
    if (!cam && !mic) {
      state = state.copyWith(
        status: AwarenessStatus.permissionDenied,
        message: 'Camera and microphone permission are required. Open settings to allow them.',
      );
      await _announce('Camera and microphone permission are required. Open settings to allow them.');
      return;
    }

    // ---- backend connection
    final ok = await _connect();
    if (!ok) return;

    _running = true;
    await _startSensors(cam: cam, mic: mic);
    state = state.copyWith(status: AwarenessStatus.active);
    await _keepAwake(true);
    final missing = <String>[
      if (!cam) 'Camera permission is required for visual awareness.',
      if (!mic) 'Microphone permission is required for sound awareness.',
    ];
    if (missing.isNotEmpty) state = state.copyWith(message: missing.join(' '));
    await _announce(missing.isEmpty ? 'Awareness mode on.' : 'Awareness mode on, with limited sensors. ${missing.first}');
  }

  Future<bool> _connect({int attempts = 1}) async {
    final socket = ref.read(socketProvider);
    final url = ref.read(settingsProvider).backend;
    for (var i = 0; i < attempts; i++) {
      try {
        await socket.connect(url);
        _evSub?.cancel();
        _modelSub?.cancel();
        _closedSub?.cancel();
        _evSub = socket.events.listen((e) => unawaited(ingest(e)));
        _modelSub = socket.models.listen(_onModels);
        _closedSub = socket.closed.listen((_) => _onSocketClosed());
        _statusTimer?.cancel();
        _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!_allModelsReady) socket.requestStatus();
        });
        return true;
      } catch (_) {
        if (i < attempts - 1) await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    const msg = "Can't reach the HearAware server. Check your network and the server address in Settings.";
    state = state.copyWith(status: AwarenessStatus.error, message: msg);
    await _announce(msg);
    return false;
  }

  bool get _allModelsReady => state.models.length == 3 && state.models.values.every((v) => v == 'ready');

  void _onModels(Map<String, String> m) {
    final notReady = m.entries.where((e) => e.value != 'ready').map((e) => e.key).toList();
    state = state.copyWith(
      models: m,
      message: notReady.isEmpty ? null : 'Some AI models are not ready yet: ${notReady.join(', ')}.',
      clearMessage: notReady.isEmpty && (state.message?.startsWith('Some AI models') ?? false),
    );
  }

  Future<void> _onSocketClosed() async {
    if (!_running || state.mode != AwarenessMode.real) return;
    state = state.copyWith(status: AwarenessStatus.initializing, message: 'Connection lost. Reconnecting...');
    final ok = await _connect(attempts: 3);
    if (ok) {
      state = state.copyWith(status: AwarenessStatus.active, clearMessage: true);
    } else {
      await _stopSensors();
      _running = false;
    }
  }

  Future<void> _startSensors({required bool cam, required bool mic}) async {
    if (_sensorsOn) return;
    _sensorsOn = true;
    if (cam) {
      try {
        await ref.read(yoloServiceProvider).start();
        state = state.copyWith(camera: SensorStatus.on);
      } catch (_) {
        state = state.copyWith(camera: SensorStatus.unavailable, message: 'Camera unavailable.');
      }
    }
    if (mic) {
      try {
        await ref.read(yamnetServiceProvider).start();
        state = state.copyWith(microphone: SensorStatus.on);
      } catch (_) {
        state = state.copyWith(microphone: SensorStatus.unavailable, message: 'Microphone unavailable.');
      }
    }
  }

  Future<void> _stopSensors() async {
    _sensorsOn = false;
    try {
      await ref.read(yoloServiceProvider).stop();
    } catch (_) {}
    try {
      await ref.read(yamnetServiceProvider).stop();
    } catch (_) {}
    state = state.copyWith(
      camera: state.camera == SensorStatus.denied ? SensorStatus.denied : SensorStatus.off,
      microphone: state.microphone == SensorStatus.denied ? SensorStatus.denied : SensorStatus.off,
    );
  }

  Future<void> pause() async {
    if (!_running || state.status == AwarenessStatus.paused) return;
    _demoRun++;
    await _stopSensors(); // privacy: nothing is captured while paused
    state = state.copyWith(status: AwarenessStatus.paused);
    await _announce('Paused.');
  }

  Future<void> resume() async {
    if (!_running || state.status != AwarenessStatus.paused) return;
    if (state.mode == AwarenessMode.real) {
      await _startSensors(
        cam: state.camera != SensorStatus.denied,
        mic: state.microphone != SensorStatus.denied,
      );
    }
    state = state.copyWith(status: AwarenessStatus.active);
    await _announce('Resumed.');
  }

  Future<void> stop() async {
    _demoRun++;
    _running = false;
    _cancelAll();
    await _stopSensors();
    try {
      await ref.read(socketProvider).close();
    } catch (_) {}
    await ref.read(ttsServiceProvider).stop();
    await _keepAwake(false);
    _fusion.flush(force: true);
    state = state.copyWith(status: AwarenessStatus.idle, clearActive: true, clearMessage: true);
  }

  void openAppSettings() => ref.read(permissionHelperProvider).openSettings();

  // ---------------------------------------------------------------- the pipeline
  /// Single entry point for every raw event (real models and demo scenarios alike).
  Future<void> ingest(AwarenessEvent e, {bool demo = false}) async {
    if (state.status == AwarenessStatus.paused) return;
    final out = _fusion.process(e);
    _armFlush(demo);
    for (final ev in out) {
      await _decide(ev, demo);
    }
  }

  /// Releases held sightings / lone sounds once nothing confirmed them. A single timer is kept alive
  /// (never re-created per event) so a steady 5 FPS stream cannot starve it.
  void _armFlush(bool demo) {
    if (!_fusion.hasPending || (_flushTimer?.isActive ?? false)) return;
    _flushTimer = Timer(_fusion.hold + const Duration(milliseconds: 30), () {
      for (final ev in _fusion.flush()) {
        unawaited(_decide(ev, demo));
      }
      _armFlush(demo);
    });
  }

  Future<void> _decide(AwarenessEvent ev, bool demo) async {
    final profile = state.profile ?? UserProfile.blind;
    _pulse(AwarenessStatus.processing);
    final d = _relevance.evaluate(ev, profile);
    if (!d.deliver) {
      state = state.copyWith(suppressed: state.suppressed + 1);
      return;
    }
    _pulse(AwarenessStatus.eventDetected);
    final alert = AlertBuilder.build(ev, d.priority, isDemo: demo || state.mode == AwarenessMode.demo);
    await _deliver(alert, profile);
  }

  Future<void> _deliver(Alert a, UserProfile profile) async {
    final history = [a, ...state.history].take(AppConstants.historyLimit).toList();
    state = state.copyWith(latest: a, history: history);

    if (profile == UserProfile.blind) {
      await ref.read(ttsServiceProvider).speak(a.spokenText, interrupt: a.priority == Priority.high);
    } else {
      state = state.copyWith(activeAlert: a); // shown as a large, high-contrast, persistent alert
      _dismissTimer?.cancel();
      if (a.priority != Priority.high) {
        _dismissTimer = Timer(AppConstants.mediumAlertAutoDismiss, () {
          if (state.activeAlert?.id == a.id) state = state.copyWith(clearActive: true);
        });
      }
    }
    _pulse(AwarenessStatus.alertDelivered);
    unawaited(ref.read(settingsStoreProvider).saveHistory(history));
    unawaited(ref.read(firebaseServiceProvider).saveEvent(a));
  }

  /// High-priority visual alerts stay until the user acknowledges them.
  void acknowledge() {
    _dismissTimer?.cancel();
    state = state.copyWith(clearActive: true);
  }

  // ---------------------------------------------------------------- demo
  Future<void> runDemo(DemoScenario s, {double delayScale = 1.0}) async {
    if (!_running || state.mode != AwarenessMode.demo || state.status == AwarenessStatus.paused) return;
    final run = ++_demoRun;
    // Every scenario is a fresh situation: clear cooldowns/fusion memory so it can be replayed on stage.
    _relevance.reset();
    _fusion.reset();
    for (final step in s.steps) {
      final wait = step.delay * delayScale;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (run != _demoRun || !_running) return;
      await ingest(step.event(), demo: true);
    }
  }

  // ---------------------------------------------------------------- helpers
  void _pulse(AwarenessStatus s) {
    if (!_running || state.status == AwarenessStatus.paused || state.status == AwarenessStatus.initializing) return;
    state = state.copyWith(status: s);
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 900), () {
      if (_running && state.status != AwarenessStatus.paused && state.status != AwarenessStatus.initializing) {
        state = state.copyWith(status: AwarenessStatus.active);
      }
    });
  }

  Future<void> _announce(String text) async {
    if (state.profile == UserProfile.blind) {
      await ref.read(ttsServiceProvider).speak(text, interrupt: true);
    }
  }

  Future<void> _keepAwake(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {}
  }

  void _cancelAll() {
    _flushTimer?.cancel();
    _pulseTimer?.cancel();
    _statusTimer?.cancel();
    _dismissTimer?.cancel();
    _evSub?.cancel();
    _modelSub?.cancel();
    _closedSub?.cancel();
  }

  bool get whisperReady => WhisperService.isReady(state.models);

  Future<void> clearHistory() async {
    state = state.copyWith(history: const [], suppressed: 0);
    await ref.read(settingsStoreProvider).saveHistory(const []);
  }
}
