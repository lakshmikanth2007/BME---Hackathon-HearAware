import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/alert_visuals.dart';
import '../models/detection.dart';

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.alert});
  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final arrow = arrowForDirection(alert.directionReliable ? alert.direction : 'unknown');
    final urgent = alert.priority == Priority.high;
    return Semantics(
      label: '${alert.spokenText} ${timeAgo(alert.timestamp)}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(iconForEvent(alert.eventKey), size: 34, color: urgent ? AppColors.danger : AppColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(alert.spokenText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(
                '${urgent ? 'URGENT' : 'NOTICE'} · ${timeAgo(alert.timestamp)}${alert.isDemo ? ' · DEMO' : ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
            ]),
          ),
          if (arrow != null) Icon(arrow, size: 28, color: AppColors.text),
        ]),
      ),
    );
  }
}
