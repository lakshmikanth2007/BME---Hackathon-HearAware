import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearaware/core/providers.dart';
import 'package:hearaware/core/theme/app_theme.dart';
import 'package:hearaware/features/awareness/awareness_controller.dart';
import 'package:hearaware/features/onboarding/onboarding_screen.dart';
import 'package:hearaware/models/detection.dart';
import 'package:hearaware/models/user_profile.dart';
import 'package:hearaware/widgets/alert_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  testWidgets('onboarding offers BLIND and DEAF with semantic labels; choosing one sets the profile', (tester) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      ttsServiceProvider.overrideWithValue(FakeTts()),
      permissionHelperProvider.overrideWithValue(FakePerms()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(), home: const OnboardingScreen()),
    ));
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('BLIND')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('DEAF')), findsOneWidget);

    await tester.tap(find.text('DEAF'));
    await tester.pumpAndSettle();
    expect(container.read(awarenessProvider).profile, UserProfile.deaf);
    expect(find.text('Camera and microphone'), findsOneWidget); // permission explanation step
    semantics.dispose();
  });

  testWidgets('visual alert shows title, direction and acknowledge button', (tester) async {
    var acked = false;
    final alert = Alert(
      id: '1',
      title: 'VEHICLE HORN',
      spokenText: 'Vehicle horn on your left.',
      eventKey: 'vehicle horn',
      direction: 'left',
      directionReliable: true,
      priority: Priority.high,
      timestamp: DateTime.now(),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [AlertOverlay(alert: alert, flash: false, onAcknowledge: () => acked = true)]),
      ),
    ));
    expect(find.text('VEHICLE HORN'), findsOneWidget);
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);
    await tester.tap(find.text('GOT IT'));
    expect(acked, true);
  });
}
