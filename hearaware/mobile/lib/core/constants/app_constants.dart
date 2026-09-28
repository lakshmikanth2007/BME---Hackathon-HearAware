class AppConstants {
  static const appName = 'HearAware';
  static const tagline = 'See with sound. Hear with light.';

  /// 10.0.2.2 reaches the host machine from the Android emulator.
  /// On a real phone set your laptop's LAN IP in Settings (e.g. 192.168.1.20:8000).
  static const defaultBackend = '10.0.2.2:8000';

  /// Frame sampling for AI processing (spec: 5-10 FPS, never every frame).
  static const frameFps = 5;

  static const historyLimit = 50;
  static const mediumAlertAutoDismiss = Duration(seconds: 7);
  static const connectTimeout = Duration(seconds: 6);
}
