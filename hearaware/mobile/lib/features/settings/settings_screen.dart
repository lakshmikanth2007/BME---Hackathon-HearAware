import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../widgets/big_button.dart';
import '../awareness/awareness_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _backend = TextEditingController(text: ref.read(settingsProvider).backend);

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }

  Future<void> _authDialog() async {
    final fb = ref.read(firebaseServiceProvider);
    final email = TextEditingController();
    final pass = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Account'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!fb.available)
              const Text('Cloud account is not configured for this build. HearAware works fully without it.'),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: AppColors.danger))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final e = await fb.register(email.text, pass.text);
                if (e == null && ctx.mounted) {
                  Navigator.pop(ctx);
                } else {
                  setD(() => error = e);
                }
              },
              child: const Text('Register'),
            ),
            FilledButton(
              onPressed: () async {
                final e = await fb.signIn(email.text, pass.text);
                if (e == null && ctx.mounted) {
                  Navigator.pop(ctx);
                } else {
                  setD(() => error = e);
                }
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(awarenessProvider.select((s) => s.profile)) ?? UserProfile.blind;
    final fb = ref.watch(firebaseServiceProvider);
    final n = ref.read(settingsProvider.notifier);
    final user = fb.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<UserProfile>(
            style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            segments: const [
              ButtonSegment(value: UserProfile.blind, label: Text('BLIND'), icon: Icon(Icons.volume_up)),
              ButtonSegment(value: UserProfile.deaf, label: Text('DEAF'), icon: Icon(Icons.visibility)),
            ],
            selected: {profile},
            onSelectionChanged: (v) => ref.read(awarenessProvider.notifier).setProfile(v.first),
          ),
          const SizedBox(height: 24),
          const Text('Speech speed (Blind profile)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Semantics(
            label: 'Speech speed',
            child: Slider(
              value: settings.speechRate,
              min: 0.3,
              max: 0.8,
              divisions: 10,
              label: settings.speechRate.toStringAsFixed(2),
              onChanged: (v) => n.update(settings.copyWith(speechRate: v)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Screen pulse on alerts (Deaf profile)', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Three gentle pulses. Turn off if light sensitive.'),
            value: settings.flash,
            onChanged: (v) => n.update(settings.copyWith(flash: v)),
          ),
          const SizedBox(height: 16),
          const Text('AI server (Real Mode)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _backend,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Address, e.g. 192.168.1.20:8000',
            ),
            onSubmitted: (v) => n.update(settings.copyWith(backend: v.trim())),
          ),
          const SizedBox(height: 10),
          BigButton(label: 'SAVE SERVER ADDRESS', height: 56, filled: false, onPressed: () {
            n.update(settings.copyWith(backend: _backend.text.trim()));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
          }),
          const SizedBox(height: 24),
          const Text('Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(user == null ? 'Not signed in (local-only mode)' : 'Signed in as ${user.email}',
              style: const TextStyle(fontSize: 16, color: AppColors.textDim)),
          const SizedBox(height: 8),
          user == null
              ? BigButton(label: 'SIGN IN / REGISTER', height: 56, filled: false, onPressed: _authDialog)
              : BigButton(label: 'SIGN OUT', height: 56, filled: false, onPressed: () async {
                  await fb.signOut();
                  if (mounted) setState(() {});
                }),
          const SizedBox(height: 24),
          const Text('Privacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'The camera and microphone run only while Awareness Mode is on. Video and audio are processed in memory '
            'and never stored. Only short text events (like "Vehicle horn on your left") are saved.',
            style: TextStyle(fontSize: 16, color: AppColors.textDim, height: 1.35),
          ),
          const SizedBox(height: 16),
          BigButton(label: 'CLEAR HISTORY', height: 56, filled: false, color: AppColors.danger,
              onPressed: () => ref.read(awarenessProvider.notifier).clearHistory()),
        ]),
      ),
    );
  }
}
