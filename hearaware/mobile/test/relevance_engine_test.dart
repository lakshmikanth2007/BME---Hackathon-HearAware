import 'package:flutter_test/flutter_test.dart';
import 'package:hearaware/models/detection.dart';
import 'package:hearaware/models/user_profile.dart';
import 'package:hearaware/relevance/relevance_engine.dart';

import 'helpers.dart';

void main() {
  late Clock clock;
  late RelevanceEngine r;
  setUp(() {
    clock = Clock();
    r = RelevanceEngine(clock: clock.now);
  });

  test('priority classification', () {
    expect(RelevanceEngine.classify(ev('audio', 'alarm', .9)), Priority.high);
    expect(RelevanceEngine.classify(ev('audio', 'horn', .9)), Priority.high);
    expect(RelevanceEngine.classify(ev('vision', 'person', .9)), Priority.medium);
    expect(RelevanceEngine.classify(ev('vision', 'car', .9)), Priority.medium);
    expect(RelevanceEngine.classify(ev('vision', 'car', .9, approaching: true)), Priority.high);
    expect(RelevanceEngine.classify(ev('vision', 'chair', .9)), Priority.low);
  });

  test('low-priority events never delivered', () {
    for (final name in ['chair', 'bottle', 'laptop', 'phone']) {
      expect(r.evaluate(ev('vision', name, .95), UserProfile.blind).deliver, false, reason: name);
    }
  });

  test('confidence threshold', () {
    expect(r.evaluate(ev('vision', 'person', .4), UserProfile.blind).deliver, false);
    expect(r.evaluate(ev('vision', 'person', .8), UserProfile.blind).deliver, true);
    expect(r.evaluate(ev('audio', 'alarm', .2), UserProfile.blind).deliver, false);
  });

  test('duplicate suppression and cooldown expiry', () {
    expect(r.evaluate(ev('audio', 'alarm', .9), UserProfile.blind).deliver, true);
    expect(r.evaluate(ev('audio', 'alarm', .9), UserProfile.blind).deliver, false);
    clock.advance(const Duration(seconds: 5));
    expect(r.evaluate(ev('audio', 'alarm', .9), UserProfile.blind).deliver, true);
  });

  test('deaf profile suppresses vision-only medium events the user can already see', () {
    expect(r.evaluate(ev('vision', 'person', .9), UserProfile.deaf).deliver, false);
    expect(r.evaluate(ev('audio', 'doorbell', .8), UserProfile.deaf).deliver, true);
  });

  test('alarm reaches both profiles', () {
    for (final p in UserProfile.values) {
      final e = RelevanceEngine(clock: clock.now);
      expect(e.evaluate(ev('audio', 'alarm', .9), p).deliver, true);
    }
  });

  test('medium vision chatter is covered by a fresh high-priority alert', () {
    expect(r.evaluate(ev('fusion', 'vehicle horn', .9, dir: 'left', dirConf: .7), UserProfile.blind).deliver, true);
    clock.advance(const Duration(seconds: 3));
    final d = r.evaluate(ev('vision', 'car', .9), UserProfile.blind);
    expect(d.deliver, false);
    expect(d.reason, 'covered by recent alert');
  });

  test('rate limit keeps medium events from stacking', () {
    expect(r.evaluate(ev('vision', 'person', .9), UserProfile.blind).deliver, true);
    clock.advance(const Duration(milliseconds: 500));
    expect(r.evaluate(ev('audio', 'doorbell', .9), UserProfile.blind).deliver, false);
    clock.advance(const Duration(seconds: 2));
    expect(r.evaluate(ev('audio', 'doorbell', .9), UserProfile.blind).deliver, true);
  });

  test('speech: same sentence suppressed, new sentence delivered', () {
    expect(r.evaluate(ev('speech', 'speech', .9, text: 'Your bus is here'), UserProfile.blind).deliver, true);
    clock.advance(const Duration(seconds: 3));
    expect(r.evaluate(ev('speech', 'speech', .9, text: 'your bus is here'), UserProfile.blind).deliver, false);
    expect(r.evaluate(ev('speech', 'speech', .9, text: 'Hello there'), UserProfile.blind).deliver, true);
  });

  test('score orders priorities', () {
    final hi = r.evaluate(ev('audio', 'alarm', .9), UserProfile.blind).score;
    final med = RelevanceEngine(clock: clock.now).evaluate(ev('vision', 'person', .9), UserProfile.blind).score;
    expect(hi, greaterThan(med));
  });
}
