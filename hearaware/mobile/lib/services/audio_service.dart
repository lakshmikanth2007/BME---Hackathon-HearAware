import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Streams 16 kHz mono PCM16 from the microphone (the format YAMNet and Whisper expect).
class AudioService {
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  Future<void> start(void Function(Uint8List pcm) onPcm) async {
    if (!await _rec.hasPermission()) throw StateError('microphone_denied');
    final stream = await _rec.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
    );
    _sub = stream.listen(onPcm);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      if (await _rec.isRecording()) await _rec.stop();
    } catch (_) {}
  }
}
