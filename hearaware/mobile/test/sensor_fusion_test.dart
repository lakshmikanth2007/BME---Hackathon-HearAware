import 'package:flutter_test/flutter_test.dart';
import 'package:hearaware/fusion/sensor_fusion.dart';

import 'helpers.dart';

void main() {
  late Clock clock;
  late SensorFusion f;
  setUp(() {
    clock = Clock();
    f = SensorFusion(clock: clock.now);
  });

  test('car (left) + horn -> one fused "vehicle horn" on the left', () {
    expect(f.process(ev('vision', 'car', .91, dir: 'left', dirConf: .68)), isEmpty); // sighting held briefly
    expect(f.hasPending, true);
    clock.advance(const Duration(milliseconds: 600));
    final out = f.process(ev('audio', 'horn', .87));
    expect(out.length, 1);
    expect(out.first.source, 'fusion');
    expect(out.first.event, 'vehicle horn');
    expect(out.first.direction, 'left');
    expect(out.first.confidence, closeTo(0.89, 0.001));
  });

  test('horn first, car second within the window -> fused', () {
    expect(f.process(ev('audio', 'horn', .8)), isEmpty); // held briefly
    expect(f.hasPending, true);
    clock.advance(const Duration(milliseconds: 200));
    final out = f.process(ev('vision', 'bus', .9, dir: 'right', dirConf: .7));
    expect(out.single.event, 'vehicle horn');
    expect(out.single.direction, 'right');
    expect(f.hasPending, false);
  });

  test('lone horn is released after the hold time, unfused, direction unknown', () {
    f.process(ev('audio', 'horn', .8));
    expect(f.flush(), isEmpty);
    clock.advance(const Duration(milliseconds: 400));
    final out = f.flush();
    expect(out.single.event, 'horn');
    expect(out.single.source, 'audio');
    expect(out.single.direction, 'unknown');
  });

  test('stale sighting outside the window is not fused', () {
    f.process(ev('vision', 'car', .9, dir: 'left', dirConf: .7));
    clock.advance(const Duration(seconds: 4));
    expect(f.process(ev('audio', 'horn', .8)), isEmpty); // pending, not fused
    expect(f.hasPending, true);
  });

  test('unreliable vision direction is not invented; falls back to reliable audio direction, else unknown', () {
    f.process(ev('vision', 'car', .9, dir: 'left', dirConf: .3));
    var out = f.process(ev('audio', 'horn', .8, dir: 'right', dirConf: .55));
    expect(out.single.direction, 'right');

    final f2 = SensorFusion(clock: clock.now);
    f2.process(ev('vision', 'car', .9, dir: 'left', dirConf: .3));
    out = f2.process(ev('audio', 'siren', .8));
    expect(out.single.event, 'vehicle siren');
    expect(out.single.direction, 'unknown');
  });

  test('a sighting is used for one horn only', () {
    f.process(ev('vision', 'car', .9, dir: 'left', dirConf: .7));
    expect(f.process(ev('audio', 'horn', .8)).single.source, 'fusion');
    expect(f.process(ev('audio', 'horn', .8)), isEmpty); // no unconsumed sighting left -> held
  });

  test('a plain car sighting with no horn is released after the hold, an approaching one is not delayed', () {
    f.process(ev('vision', 'car', .9, dir: 'left', dirConf: .7));
    expect(f.flush(), isEmpty);
    clock.advance(const Duration(milliseconds: 400));
    expect(f.flush().single.event, 'car');
    expect(f.process(ev('vision', 'car', .9, dir: 'left', dirConf: .7, approaching: true)).single.approaching, true);
  });

  test('non-vehicle events pass straight through', () {
    expect(f.process(ev('audio', 'alarm', .9)).single.event, 'alarm');
    expect(f.process(ev('speech', 'speech', .9, text: 'hi')).single.event, 'speech');
    expect(f.process(ev('vision', 'person', .9)).single.event, 'person');
  });
}
