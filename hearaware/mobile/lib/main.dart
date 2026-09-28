import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/awareness/awareness_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final firebase = FirebaseService();
  await firebase.init(); // safe: falls back to local-only mode if Firebase is not configured

  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      firebaseServiceProvider.overrideWithValue(firebase),
    ],
    child: const HearAwareApp(),
  ));
}

class HearAwareApp extends ConsumerWidget {
  const HearAwareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once: onboarding pushes its own routes, so the home must not flip when the profile is chosen.
    final hasProfile = ref.read(settingsStoreProvider).profile != null;
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: hasProfile ? const AwarenessScreen() : const OnboardingScreen(),
    );
  }
}
