/// Speech pipeline client. Whisper runs on the backend on VAD-gated speech segments only;
/// it is NOT an environmental sound classifier. Transcripts arrive as `speech` events.
class WhisperService {
  static bool isReady(Map<String, String> models) => models['whisper'] == 'ready';
}
