import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/alert_visuals.dart';
import '../models/detection.dart';

class LatestEventCard extends StatelessWidget {
  const LatestEventCard({super.key, required this.alert, required this.running});
  final Alert? alert;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final arrow = a == null ? null : arrowForDirection(a.directionReliable ? a.direction : 'unknown');
    final text = a?.spokenText ?? (running ? 'Listening and watching for what matters...' : 'Nothing yet. Start Awareness Mode.');
    return Semantics(
      liveRegion: true,
      label: 'Latest important event. $text',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: a?.priority == Priority.high ? AppColors.danger : AppColors.surfaceHi, width: 3),
        ),
        child: Row(children: [
          Icon(a == null ? Icons.hearing : iconForEvent(a.eventKey), size: 56, color: AppColors.accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LATEST IMPORTANT EVENT',
                  style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: AppColors.textDim)),
              const SizedBox(height: 6),
              Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
              if (a != null) ...[
                const SizedBox(height: 4),
                Text(timeAgo(a.timestamp), style: const TextStyle(fontSize: 14, color: AppColors.textDim)),
              ],
            ]),
          ),
          if (arrow != null) Icon(arrow, size: 44, color: AppColors.text),
        ]),
      ),
    );
  }
}
