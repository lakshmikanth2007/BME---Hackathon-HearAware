import 'package:flutter_test/flutter_test.dart';
import 'package:hearaware/models/awareness_event.dart';

void main() {
  test('parses backend JSON into a normalized event', () {
    final e = AwarenessEvent.fromJson({
      'id': 'abc',
      'timestamp': '2026-01-01T10:00:00+00:00',
      'source': 'vision',
      'event': 'car',
      'description': 'Car detected',
      'confidence': 0.92,
      'direction': 'left',
      'direction_confidence': 0.68,
      'speech_text': null,
    });
    expect(e.event, 'car');
    expect(e.direction, 'left');
    expect(e.directionConfidence, 0.68);
    expect(e.confidence, 0.92); // separate from direction confidence
  });

  test('speech event keeps text', () {
    final e = AwarenessEvent.fromJson({'source': 'speech', 'event': 'speech', 'confidence': 0.91, 'speech_text': 'Your bus is here'});
    expect(e.speechText, 'Your bus is here');
  });

  test('invalid direction falls back to unknown with zero direction confidence', () {
    final e = AwarenessEvent.create(source: 'audio', event: 'horn', confidence: 0.8, direction: 'sideways', directionConfidence: 0.9);
    expect(e.direction, 'unknown');
    expect(e.directionConfidence, 0);
    expect(e.directionReliable, false);
  });

  test('confidence is clamped and missing fields do not crash', () {
    final e = AwarenessEvent.fromJson({'confidence': 4});
    expect(e.confidence, 1.0);
    expect(e.event, 'unknown');
  });

  test('direction reliability needs both a known direction and enough confidence', () {
    expect(AwarenessEvent.create(source: 'vision', event: 'car', confidence: 0.9, direction: 'left', directionConfidence: 0.49).directionReliable, false);
    expect(AwarenessEvent.create(source: 'vision', event: 'car', confidence: 0.9, direction: 'left', directionConfidence: 0.5).directionReliable, true);
  });

  test('json round trip', () {
    final e = AwarenessEvent.create(source: 'audio', event: 'alarm', confidence: 0.7);
    final back = AwarenessEvent.fromJson(e.toJson());
    expect(back.event, 'alarm');
    expect(back.confidence, 0.7);
  });
}
