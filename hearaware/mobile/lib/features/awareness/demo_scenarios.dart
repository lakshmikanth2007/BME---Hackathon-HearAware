import '../../models/awareness_event.dart';

class DemoStep {
  const DemoStep(this.delay, this.event);
  final Duration delay;
  final AwarenessEvent Function() event;
}

class DemoScenario {
  const DemoScenario(this.id, this.title, this.subtitle, this.steps);
  final String id;
  final String title;
  final String subtitle;
  final List<DemoStep> steps;
}

/// Demo Mode feeds *raw normalized events* (what the models would emit) into the SAME
/// fusion -> relevance -> output pipeline as Real Mode. There is no separate demo UI or output path.
class DemoScenarios {
  static AwarenessEvent _v(String e, double c, String dir, double dc) =>
      AwarenessEvent.create(source: 'vision', event: e, confidence: c, direction: dir, directionConfidence: dc);

  static final List<DemoScenario> all = [
    DemoScenario('car_horn', 'Car + horn on left', 'Camera sees a car, microphone hears a horn', [
      DemoStep(Duration.zero, () => _v('car', 0.91, 'left', 0.68)),
      DemoStep(
        const Duration(milliseconds: 250),
        () => AwarenessEvent.create(source: 'audio', event: 'horn', description: 'Vehicle horn', confidence: 0.87),
      ),
    ]),
    DemoScenario('alarm', 'Alarm', 'Microphone hears an alarm', [
      DemoStep(
        Duration.zero,
        () => AwarenessEvent.create(source: 'audio', event: 'alarm', description: 'Alarm', confidence: 0.9),
      ),
    ]),
    DemoScenario('speech', 'Person speaking', 'Whisper transcribes: "Your bus is here"', [
      DemoStep(
        Duration.zero,
        () => AwarenessEvent.create(
          source: 'speech',
          event: 'speech',
          description: 'Person speaking',
          confidence: 0.91,
          speechText: 'Your bus is here',
        ),
      ),
    ]),
    DemoScenario('background', 'Background activity', 'Chairs, bottles, laptops - all suppressed', [
      DemoStep(Duration.zero, () => _v('chair', 0.9, 'front', 0.7)),
      DemoStep(const Duration(milliseconds: 300), () => _v('bottle', 0.82, 'left', 0.7)),
      DemoStep(const Duration(milliseconds: 300), () => _v('laptop', 0.88, 'front', 0.7)),
      DemoStep(const Duration(milliseconds: 300), () => _v('chair', 0.9, 'front', 0.7)),
      DemoStep(const Duration(milliseconds: 300), () => _v('phone', 0.86, 'right', 0.7)),
      DemoStep(const Duration(milliseconds: 300), () => _v('person', 0.35, 'right', 0.6)),
    ]),
  ];
}
