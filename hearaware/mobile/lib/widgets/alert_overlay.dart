import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/alert_visuals.dart';
import '../models/detection.dart';
import 'big_button.dart';

/// Full-screen visual alert for the Deaf profile: huge text, high contrast, icon + words (not colour alone),
/// three gentle screen pulses (well under 3 flashes/second), persistent until acknowledged.
class AlertOverlay extends StatefulWidget {
  const AlertOverlay({super.key, required this.alert, required this.flash, required this.onAcknowledge});
  final Alert alert;
  final bool flash;
  final VoidCallback onAcknowledge;

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2100));

  @override
  void initState() {
    super.initState();
    if (widget.flash) _c.forward();
  }

  @override
  void didUpdateWidget(covariant AlertOverlay old) {
    super.didUpdateWidget(old);
    if (old.alert.id != widget.alert.id && widget.flash) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final urgent = a.priority == Priority.high;
    final arrow = arrowForDirection(a.directionReliable ? a.direction : 'unknown');
    final dirText = a.directionLabel ?? (_needsDirection(a) ? 'DIRECTION UNCERTAIN' : null);
    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: '${urgent ? 'Urgent alert' : 'Notice'}. ${a.spokenText}',
        child: Material(
          color: urgent ? const Color(0xFF6E0010) : const Color(0xFF0A2A5E),
          child: Stack(children: [
            Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 6), borderRadius: BorderRadius.circular(24)),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text(urgent ? 'URGENT' : 'NOTICE',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
                    const Spacer(),
                    Icon(iconForEvent(a.eventKey), size: 140, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(a.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 46, height: 1.05, fontWeight: FontWeight.w900, color: Colors.white)),
                    if (dirText != null) ...[
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (arrow != null) Icon(arrow, size: 56, color: AppColors.accent),
                        if (arrow != null) const SizedBox(width: 10),
                        Flexible(
                          child: Text(dirText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: arrow != null ? 44 : 26, fontWeight: FontWeight.w900, color: AppColors.accent)),
                        ),
                      ]),
                    ],
                    if ((a.speechText ?? '').isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('"${a.speechText}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                    const Spacer(),
                    BigButton(
                      label: urgent ? 'GOT IT' : 'DISMISS',
                      icon: Icons.check_circle,
                      onPressed: widget.onAcknowledge,
                      semanticsLabel: 'Acknowledge alert',
                    ),
                  ]),
                ),
              ),
            ),
            if (widget.flash)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final t = (_c.value * 3) % 1.0; // three pulses
                      final pulse = _c.isCompleted ? 0.0 : (1 - (t - 0.5).abs() * 2);
                      return ColoredBox(color: Colors.white.withOpacity(0.35 * pulse));
                    },
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  static bool _needsDirection(Alert a) => const {'horn', 'siren', 'vehicle horn', 'vehicle siren'}.contains(a.eventKey);
}
