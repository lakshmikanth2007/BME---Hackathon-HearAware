import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hearaware/core/permissions/permission_helper.dart';
import 'package:hearaware/core/providers.dart';
import 'package:hearaware/models/awareness_event.dart';
import 'package:hearaware/services/tts_service.dart';
import 'package:hearaware/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTts implements TtsService {
  final spoken = <String>[];
  final interrupts = <bool>[];
  @override
  Future<void> init({double rate = 0.5}) async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    spoken.add(text);
    interrupts.add(interrupt);
  }

  @override
  Future<void> stop() async {}
}

class FakePerms implements PermissionHelper {
  FakePerms({this.camera = true, this.mic = true});
  final bool camera, mic;
  @override
  Future<bool> requestCamera() async => camera;
  @override
  Future<bool> requestMicrophone() async => mic;
  @override
  Future<void> openSettings() async {}
}

/// Test double for the network layer (TEST ONLY).
class FakeSocket implements AwarenessSocket {
  FakeSocket({this.failConnect = false});
  final bool failConnect;
  @override
  Stream<AwarenessEvent> get events => const Stream.empty();
  @override
  Stream<Map<String, String>> get models => const Stream.empty();
  @override
  Stream<void> get closed => const Stream.empty();
  @override
  Future<void> connect(String backend) async {
    if (failConnect) throw Exception('unreachable');
  }

  @override
  void sendFrame(Uint8List jpeg) {}
  @override
  void sendAudio(Uint8List pcm16, {int channels = 1}) {}
  @override
  void requestStatus() {}
  @override
  Future<void> close() async {}
}

Future<ProviderContainer> makeContainer({FakeTts? tts, FakePerms? perms, FakeSocket? socket, Map<String, Object>? prefs}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  final p = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(p),
    ttsServiceProvider.overrideWithValue(tts ?? FakeTts()),
    permissionHelperProvider.overrideWithValue(perms ?? FakePerms()),
    socketProvider.overrideWithValue(socket ?? FakeSocket()),
  ]);
  return c;
}

AwarenessEvent ev(String source, String event, double conf,
        {String dir = 'unknown', double dirConf = 0, String? text, bool approaching = false, DateTime? at}) =>
    AwarenessEvent.create(
      source: source,
      event: event,
      confidence: conf,
      direction: dir,
      directionConfidence: dirConf,
      speechText: text,
      approaching: approaching,
      at: at,
    );

class Clock {
  DateTime t = DateTime(2026, 1, 1, 12);
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
}
