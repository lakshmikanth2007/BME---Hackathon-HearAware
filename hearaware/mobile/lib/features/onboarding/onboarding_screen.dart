import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../awareness/awareness_controller.dart';
import 'permission_screen.dart';

/// Two huge halves: top = BLIND, bottom = DEAF. Usable with TalkBack and by touch alone.
/// No microphone is needed to pick a profile.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final tts = ref.read(ttsServiceProvider);
      await tts.init(rate: ref.read(settingsProvider).speechRate);
      await tts.speak('Welcome to HearAware. Tap the top half of the screen for Blind. Tap the bottom half for Deaf.');
    });
  }

  Future<void> _choose(UserProfile p) async {
    await ref.read(awarenessProvider.notifier).setProfile(p);
    if (p == UserProfile.blind) {
      await ref.read(ttsServiceProvider).speak('Blind profile selected.', interrupt: true);
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PermissionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(children: [
              Semantics(
                header: true,
                child: const Text(AppConstants.appName,
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.accent)),
              ),
              const SizedBox(height: 4),
              const Text(AppConstants.tagline, style: TextStyle(fontSize: 17, color: AppColors.textDim)),
              const SizedBox(height: 14),
              const Text('Choose how you want to be alerted', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
            ]),
          ),
          Expanded(child: _ProfileTile(profile: UserProfile.blind, icon: Icons.volume_up, hint: 'You will hear alerts', onTap: () => _choose(UserProfile.blind))),
          Expanded(child: _ProfileTile(profile: UserProfile.deaf, icon: Icons.visibility, hint: 'You will see alerts', onTap: () => _choose(UserProfile.deaf), inverted: true)),
        ]),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, required this.icon, required this.hint, required this.onTap, this.inverted = false});
  final UserProfile profile;
  final IconData icon;
  final String hint;
  final VoidCallback onTap;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final bg = inverted ? AppColors.text : AppColors.accent;
    return Semantics(
      button: true,
      label: '${profile.label.toUpperCase()}. $hint.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: SizedBox.expand(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 72, color: Colors.black),
                const SizedBox(height: 8),
                Text(profile.label.toUpperCase(),
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.black)),
                Text(hint, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
