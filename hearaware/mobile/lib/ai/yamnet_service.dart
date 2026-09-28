import 'dart:math' as math;
import 'dart:typed_data';

import '../services/audio_service.dart';
import '../services/websocket_service.dart';

/// RMS of little-endian PCM16 in [0, 1].
double rmsPcm16(Uint8List pcm) {
  final n = pcm.lengthInBytes ~/ 2;
  if (n == 0) return 0;
  final bd = ByteData.sublistView(pcm);
  double sum = 0;
  for (var i = 0; i < n; i++) {
    final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
    sum += v * v;
  }
  return math.sqrt(sum / n);
}

/// Sound pipeline client: YAMNet (environmental sounds) + Whisper (speech) run on the backend.
/// Privacy: silence is not uploaded. Audio is sent only when the mic is above the noise floor,
/// plus a short hangover so the backend can detect the end of a spoken sentence.
class YamnetService {
  YamnetService(this._audio, this._socket, {this.floor = 0.004, this.hangover = const Duration(milliseconds: 1500)});
  final AudioService _audio;
  final AwarenessSocket _socket;
  final double floor;
  final Duration hangover;
  DateTime _lastLoud = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start() => _audio.start(_onPcm);
  Future<void> stop() => _audio.stop();

  void _onPcm(Uint8List pcm) {
    final now = DateTime.now();
    if (rmsPcm16(pcm) >= floor) _lastLoud = now;
    if (now.difference(_lastLoud) <= hangover) _socket.sendAudio(pcm);
  }
}
