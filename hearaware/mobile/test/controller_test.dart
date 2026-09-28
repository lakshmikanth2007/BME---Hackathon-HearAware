import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearaware/features/awareness/awareness_controller.dart';
import 'package:hearaware/features/awareness/demo_scenarios.dart';
import 'package:hearaware/models/detection.dart';
import 'package:hearaware/models/user_profile.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile selection is applied and persisted', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    expect(c.read(awarenessProvider).profile, isNull);
    await c.read(awarenessProvider.notifier).setProfile(UserProfile.deaf);
    expect(c.read(awarenessProvider).profile, UserProfile.deaf);

    final c2 = await makeContainer(prefs: {'profile': 'blind'});
    addTearDown(c2.dispose);
    expect(c2.read(awarenessProvider).profile, UserProfile.blind);
  });

  test('Blind: car + horn -> TTS "Vehicle horn on your left." (interrupting)', () async {
    final tts = FakeTts();
    final c = await makeContainer(tts: tts);
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.blind);
    await n.ingest(ev('vision', 'car', .91, dir: 'left', dirConf: .68), demo: true);
    await n.ingest(ev('audio', 'horn', .87), demo: true);
    expect(tts.spoken, ['Vehicle horn on your left.']); // ONE useful message, not "car" + "horn"
    expect(tts.interrupts.last, true);
    expect(c.read(awarenessProvider).latest!.isDemo, true);
  });

  test('Deaf: same events -> persistent visual alert, no TTS', () async {
    final tts = FakeTts();
    final c = await makeContainer(tts: tts);
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.deaf);
    await n.ingest(ev('vision', 'car', .91, dir: 'left', dirConf: .68));
    await n.ingest(ev('audio', 'horn', .87));
    final a = c.read(awarenessProvider).activeAlert;
    expect(a, isNotNull);
    expect(a!.title, 'VEHICLE HORN');
    expect(a.directionLabel, 'LEFT');
    expect(tts.spoken, isEmpty);
    n.acknowledge();
    expect(c.read(awarenessProvider).activeAlert, isNull);
  });

  test('Blind: alarm scenario and speech scenario', () async {
    final tts = FakeTts();
    final c = await makeContainer(tts: tts);
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.blind);
    n.setMode(AwarenessMode.demo);
    await n.start();
    await n.runDemo(DemoScenarios.all[1], delayScale: 0);
    await n.runDemo(DemoScenarios.all[2], delayScale: 0);
    expect(tts.spoken, containsAll(['Alarm detected.', 'Someone says: Your bus is here']));
    await n.stop();
  });

  test('Demo background scenario is fully suppressed', () async {
    final tts = FakeTts();
    final c = await makeContainer(tts: tts);
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.blind);
    n.setMode(AwarenessMode.demo);
    await n.start();
    tts.spoken.clear();
    await n.runDemo(DemoScenarios.all[3], delayScale: 0);
    expect(tts.spoken, isEmpty);
    expect(c.read(awarenessProvider).suppressed, 6);
    expect(c.read(awarenessProvider).history, isEmpty);
    await n.stop();
  });

  test('permission denied -> PERMISSION DENIED state with a clear message', () async {
    final tts = FakeTts();
    final c = await makeContainer(perms: FakePerms(camera: false, mic: false), tts: tts);
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.blind);
    await n.start();
    final s = c.read(awarenessProvider);
    expect(s.status, AwarenessStatus.permissionDenied);
    expect(s.message, contains('permission'));
    expect(s.camera, SensorStatus.denied);
    expect(tts.spoken.last, contains('permission')); // blind users hear the problem too
  });

  test('backend unavailable -> ERROR state, no crash', () async {
    final c = await makeContainer(socket: FakeSocket(failConnect: true));
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.deaf);
    await n.start();
    final s = c.read(awarenessProvider);
    expect(s.status, AwarenessStatus.error);
    expect(s.message, contains("Can't reach"));
  });

  test('history is capped and persisted as text', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final n = c.read(awarenessProvider.notifier);
    await n.setProfile(UserProfile.deaf);
    await n.ingest(ev('audio', 'alarm', .9));
    expect(c.read(awarenessProvider).history.length, 1);
    await n.clearHistory();
    expect(c.read(awarenessProvider).history, isEmpty);
  });
}
