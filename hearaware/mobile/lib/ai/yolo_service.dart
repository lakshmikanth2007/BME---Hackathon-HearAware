import '../core/constants/app_constants.dart';
import '../services/camera_service.dart';
import '../services/websocket_service.dart';

/// Vision pipeline client: OpenCV/YOLO run on the backend (see backend/app/ai/yolo.py).
/// This side samples camera frames (5 FPS by default, not every frame) and sends compressed JPEGs.
class YoloService {
  YoloService(this._camera, this._socket);
  final CameraService _camera;
  final AwarenessSocket _socket;

  Future<void> start({int fps = AppConstants.frameFps}) => _camera.start(_socket.sendFrame, fps: fps);
  Future<void> stop() => _camera.stop();
}
