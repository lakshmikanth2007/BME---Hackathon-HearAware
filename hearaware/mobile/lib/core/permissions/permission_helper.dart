import 'package:permission_handler/permission_handler.dart';

abstract class PermissionHelper {
  Future<bool> requestCamera();
  Future<bool> requestMicrophone();
  Future<void> openSettings();
}

class PlatformPermissionHelper implements PermissionHelper {
  @override
  Future<bool> requestCamera() async => (await Permission.camera.request()).isGranted;

  @override
  Future<bool> requestMicrophone() async => (await Permission.microphone.request()).isGranted;

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
