import 'package:flutter_tts/flutter_tts.dart';

abstract class TtsService {
  Future<void> init({double rate});
  Future<void> setRate(double rate);
  Future<void> speak(String text, {bool interrupt});
  Future<void> stop();
}

/// Native Android TTS through flutter_tts (works with, and does not fight, TalkBack).
class FlutterTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  @override
  Future<void> init({double rate = 0.5}) async {
    if (_ready) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {
      _ready = false; // TTS engine missing: visual UI still shows the alert
    }
  }

  @override
  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (!_ready) await init();
    try {
      if (interrupt) await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
