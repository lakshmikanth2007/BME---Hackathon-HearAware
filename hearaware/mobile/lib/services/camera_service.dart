import 'dart:typed_data';

import 'package:camera/camera.dart';

/// Captures camera frames as JPEG. Frames are sampled (never every frame) and only used while Awareness Mode is on.
class CameraService {
  CameraController? _c;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  CameraController? get controller => _c;

  Future<void> start(void Function(Uint8List jpeg) onFrame, {int fps = 5}) async {
    final cams = await availableCameras();
    if (cams.isEmpty) throw StateError('camera_unavailable');
    final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    final c = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false, // the mic is owned by AudioService
      imageFormatGroup: ImageFormatGroup.jpeg, // JPEG frames straight from the camera: no slow YUV->RGB in Dart
    );
    await c.initialize();
    _c = c;
    final interval = Duration(milliseconds: (1000 / fps).round());
    await c.startImageStream((img) {
      final now = DateTime.now();
      if (now.difference(_last) < interval || img.planes.isEmpty) return;
      _last = now;
      onFrame(img.planes.first.bytes);
    });
  }

  Future<void> stop() async {
    final c = _c;
    _c = null;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c.dispose();
  }
}
