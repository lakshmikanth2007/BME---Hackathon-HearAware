import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../widgets/big_button.dart';
import '../awareness/awareness_controller.dart';
import '../awareness/awareness_screen.dart';

/// Explains clearly why permissions are needed, then continues either way (Demo Mode needs none).
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});
  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  String? _note;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(awarenessProvider).profile == UserProfile.blind) {
        ref.read(ttsServiceProvider).speak(
            'HearAware needs your camera and microphone, only while Awareness Mode is on. '
            'Tap the top button to allow. Tap the bottom button to try Demo Mode first.',
            interrupt: true);
      }
    });
  }

  Future<void> _allow() async {
    final perms = ref.read(permissionHelperProvider);
    final cam = await perms.requestCamera();
    final mic = await perms.requestMicrophone();
    if (!mounted) return;
    if (!cam || !mic) {
      setState(() => _note = [
            if (!cam) 'Camera permission is required for visual awareness.',
            if (!mic) 'Microphone permission is required for sound awareness.',
            'You can still use Demo Mode.',
          ].join(' '));
      if (ref.read(awarenessProvider).profile == UserProfile.blind) {
        ref.read(ttsServiceProvider).speak(_note!, interrupt: true);
      }
      return;
    }
    _continue();
  }

  void _continue() {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AwarenessScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.privacy_tip, size: 72, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text('Camera and microphone', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.text)),
            const SizedBox(height: 12),
            const Text(
              'HearAware uses the camera and microphone only while Awareness Mode is ON. '
              'Video and audio are not saved. Only short text events are kept.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, color: AppColors.textDim, height: 1.35),
            ),
            if (_note != null) ...[
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(_note!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: AppColors.danger))),
            ],
            const Spacer(),
            BigButton(label: 'ALLOW CAMERA & MIC', icon: Icons.check, onPressed: _allow),
            const SizedBox(height: 14),
            BigButton(label: 'TRY DEMO FIRST', icon: Icons.play_circle, filled: false, onPressed: _continue),
          ]),
        ),
      ),
    );
  }
}
