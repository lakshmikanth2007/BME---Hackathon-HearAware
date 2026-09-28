import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/detection.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.icon, required this.label, required this.ok, this.warn = false});
  final IconData icon;
  final String label;
  final bool ok;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.ok : (warn ? AppColors.danger : AppColors.textDim);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
        ]),
      ),
    );
  }

  static String sensorText(String name, SensorStatus s) {
    switch (s) {
      case SensorStatus.on:
        return '$name on';
      case SensorStatus.off:
        return '$name off';
      case SensorStatus.denied:
        return '$name blocked';
      case SensorStatus.unavailable:
        return '$name unavailable';
    }
  }
}
