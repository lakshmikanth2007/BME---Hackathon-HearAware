import 'package:flutter_test/flutter_test.dart';
import 'package:hearaware/models/detection.dart';
import 'package:hearaware/relevance/alert_builder.dart';

import 'helpers.dart';

void main() {
  test('fused vehicle horn on the left', () {
    final a = AlertBuilder.build(ev('fusion', 'vehicle horn', .9, dir: 'left', dirConf: .68), Priority.high);
    expect(a.spokenText, 'Vehicle horn on your left.');
    expect(a.title, 'VEHICLE HORN');
    expect(a.directionLabel, 'LEFT');
  });

  test('unreliable direction is stated honestly for directional sounds', () {
    final a = AlertBuilder.build(ev('audio', 'horn', .8), Priority.high);
    expect(a.spokenText, 'Horn detected. Direction uncertain.');
    expect(a.directionLabel, isNull);
  });

  test('alarm', () {
    expect(AlertBuilder.build(ev('audio', 'alarm', .9), Priority.high).spokenText, 'Alarm detected.');
  });

  test('speech carries the transcript', () {
    final a = AlertBuilder.build(ev('speech', 'speech', .9, text: 'Your bus is here'), Priority.medium);
    expect(a.spokenText, 'Someone says: Your bus is here');
    expect(a.speechText, 'Your bus is here');
  });

  test('approaching vehicle and plain person', () {
    expect(AlertBuilder.build(ev('vision', 'car', .9, dir: 'right', dirConf: .7, approaching: true), Priority.high).spokenText,
        'Car approaching on your right.');
    expect(AlertBuilder.build(ev('vision', 'person', .9, dir: 'front', dirConf: .7), Priority.medium).spokenText, 'Person ahead.');
  });
}
