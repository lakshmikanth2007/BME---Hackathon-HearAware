import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/yamnet_service.dart';
import '../ai/yolo_service.dart';
import '../core/permissions/permission_helper.dart';
import '../services/audio_service.dart';
import '../services/camera_service.dart';
import '../services/firebase_service.dart';
import '../services/settings_store.dart';
import '../services/tts_service.dart';
import '../services/websocket_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main()'));
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore(ref.watch(sharedPrefsProvider)));

final ttsServiceProvider = Provider<TtsService>((ref) => FlutterTtsService());
final permissionHelperProvider = Provider<PermissionHelper>((ref) => PlatformPermissionHelper());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final socketProvider = Provider<AwarenessSocket>((ref) {
  final s = WsClient();
  ref.onDispose(s.close);
  return s;
});
final cameraServiceProvider = Provider<CameraService>((ref) => CameraService());
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final yoloServiceProvider =
    Provider<YoloService>((ref) => YoloService(ref.watch(cameraServiceProvider), ref.watch(socketProvider)));
final yamnetServiceProvider =
    Provider<YamnetService>((ref) => YamnetService(ref.watch(audioServiceProvider), ref.watch(socketProvider)));

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).loadSettings();

  Future<void> update(AppSettings s) async {
    state = s;
    await ref.read(settingsStoreProvider).saveSettings(s);
    await ref.read(ttsServiceProvider).setRate(s.speechRate);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
