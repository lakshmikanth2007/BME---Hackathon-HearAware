import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/detection.dart';
import '../../models/user_profile.dart';
import '../../widgets/alert_overlay.dart';
import '../../widgets/big_button.dart';
import '../../widgets/event_tile.dart';
import '../../widgets/latest_event_card.dart';
import '../../widgets/status_pill.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'awareness_controller.dart';
import 'awareness_state.dart';
import 'demo_scenarios.dart';
import 'package:camera/camera.dart';

class AwarenessScreen extends ConsumerWidget {
  const AwarenessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(awarenessProvider);
    final c = ref.read(awarenessProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final profile = s.profile ?? UserProfile.blind;
    final demo = s.mode == AwarenessMode.demo;
    final active = s.running;

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
            // ---- header
            Row(children: [
              const Icon(Icons.hearing, color: AppColors.accent, size: 34),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(AppConstants.appName,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.accent)),
              ),
              IconButton(
                tooltip: 'History',
                iconSize: 30,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: 'Settings',
                iconSize: 30,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const Icon(Icons.settings),
              ),
            ]),
            Semantics(
              label: 'Profile: ${profile.label}. ${profile.outputLabel}.',
              excludeSemantics: true,
              child: Chip(
                avatar: Icon(profile == UserProfile.blind ? Icons.volume_up : Icons.visibility, size: 20),
                label: Text('${profile.label} profile · ${profile.outputLabel}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),

            // ---- mode switch
            Semantics(
              label: 'Mode. ${demo ? 'Demo mode' : 'Real mode'} selected.',
              child: SegmentedButton<AwarenessMode>(
                style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                segments: const [
                  ButtonSegment(value: AwarenessMode.real, label: Text('REAL MODE'), icon: Icon(Icons.sensors)),
                  ButtonSegment(value: AwarenessMode.demo, label: Text('DEMO MODE'), icon: Icon(Icons.science)),
                ],
                selected: {s.mode},
                onSelectionChanged: active ? null : (v) => c.setMode(v.first),
              ),
            ),
            if (demo)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceHi, borderRadius: BorderRadius.circular(12)),
                child: const Text('DEMO MODE: scripted events run through the same fusion, relevance and output pipeline.',
                    style: TextStyle(fontSize: 15, color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 14),

            // ---- state + sensors
            Semantics(
              liveRegion: true,
              label: 'Status: ${AwarenessViewState.statusLabel(s.status)}',
              excludeSemantics: true,
              child: Row(children: [
                Icon(_statusIcon(s.status), color: _statusColor(s.status), size: 30),
                const SizedBox(width: 10),
                Text(AwarenessViewState.statusLabel(s.status).toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text)),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              if (!demo) ...[
                StatusPill(icon: Icons.videocam, label: StatusPill.sensorText('Camera', s.camera), ok: s.camera == SensorStatus.on, warn: s.camera == SensorStatus.denied || s.camera == SensorStatus.unavailable),
                StatusPill(icon: Icons.mic, label: StatusPill.sensorText('Mic', s.microphone), ok: s.microphone == SensorStatus.on, warn: s.microphone == SensorStatus.denied || s.microphone == SensorStatus.unavailable),
                if (s.models.isNotEmpty)
                  StatusPill(
                    icon: Icons.memory,
                    label: s.models.values.every((v) => v == 'ready') ? 'AI ready' : 'AI loading',
                    ok: s.models.values.every((v) => v == 'ready'),
                  ),
              ] else
                const StatusPill(icon: Icons.science, label: 'Demo', ok: true),
            ]),
            if (s.message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: (s.status == AwarenessStatus.error || s.status == AwarenessStatus.permissionDenied) ? AppColors.danger : AppColors.accent,
                        width: 2),
                  ),
                  child: Row(children: [
                    Icon((s.status == AwarenessStatus.error || s.status == AwarenessStatus.permissionDenied) ? Icons.error_outline : Icons.info_outline, color: AppColors.text),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.message!, style: const TextStyle(fontSize: 16, color: AppColors.text))),
                  ]),
                ),
              ),
            ],
            if (s.status == AwarenessStatus.permissionDenied) ...[
              const SizedBox(height: 10),
              BigButton(label: 'OPEN SETTINGS', icon: Icons.settings, filled: false, height: 60, onPressed: c.openAppSettings),
            ],
            const SizedBox(height: 16),

            // ---- camera preview (real mode, sighted helpers / Deaf users)
            if (!demo && s.camera == SensorStatus.on) _CameraPreview(),

            // ---- latest event
            LatestEventCard(alert: s.latest, running: active),
            const SizedBox(height: 16),

            // ---- primary action
            if (!active)
              BigButton(
                label: 'START AWARENESS MODE',
                icon: Icons.play_arrow,
                height: 92,
                onPressed: s.status == AwarenessStatus.initializing ? null : c.start,
              )
            else ...[
              BigButton(label: 'STOP AWARENESS MODE', icon: Icons.stop, color: AppColors.danger, filled: false, height: 84, onPressed: c.stop),
              const SizedBox(height: 10),
              s.status == AwarenessStatus.paused
                  ? BigButton(label: 'RESUME', icon: Icons.play_arrow, height: 60, onPressed: c.resume)
                  : BigButton(label: 'PAUSE', icon: Icons.pause, filled: false, height: 60, onPressed: c.pause),
            ],

            // ---- demo scenarios
            if (demo && active) ...[
              const SizedBox(height: 18),
              const Text('Scenarios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 8),
              for (final sc in DemoScenarios.all) _ScenarioButton(scenario: sc, onTap: () => c.runDemo(sc)),
            ],

            // ---- filtered count: the "understands what matters" proof
            if (active || s.suppressed > 0) ...[
              const SizedBox(height: 14),
              Semantics(
                label: '${s.suppressed} background events filtered out',
                excludeSemantics: true,
                child: Row(children: [
                  const Icon(Icons.filter_alt, color: AppColors.textDim),
                  const SizedBox(width: 8),
                  Text('${s.suppressed} background events filtered', style: const TextStyle(fontSize: 15, color: AppColors.textDim)),
                ]),
              ),
            ],

            // ---- history preview
            if (s.history.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Text('Recent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text))),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  child: const Text('View all', style: TextStyle(fontSize: 16)),
                ),
              ]),
              for (final a in s.history.take(3)) EventTile(alert: a),
            ],
          ]),

          // ---- visual alert (Deaf profile)
          if (profile == UserProfile.deaf && s.activeAlert != null)
            AlertOverlay(alert: s.activeAlert!, flash: settings.flash, onAcknowledge: c.acknowledge),
        ]),
      ),
    );
  }

  static IconData _statusIcon(AwarenessStatus s) {
    switch (s) {
      case AwarenessStatus.idle:
        return Icons.power_settings_new;
      case AwarenessStatus.initializing:
        return Icons.hourglass_top;
      case AwarenessStatus.active:
        return Icons.sensors;
      case AwarenessStatus.processing:
        return Icons.autorenew;
      case AwarenessStatus.eventDetected:
        return Icons.priority_high;
      case AwarenessStatus.alertDelivered:
        return Icons.check_circle;
      case AwarenessStatus.paused:
        return Icons.pause_circle;
      case AwarenessStatus.error:
        return Icons.error;
      case AwarenessStatus.permissionDenied:
        return Icons.block;
    }
  }

  static Color _statusColor(AwarenessStatus s) {
    if (s == AwarenessStatus.error || s == AwarenessStatus.permissionDenied) return AppColors.danger;
    if (s == AwarenessStatus.idle || s == AwarenessStatus.paused) return AppColors.textDim;
    return AppColors.ok;
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({required this.scenario, required this.onTap});
  final DemoScenario scenario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: 'Run scenario: ${scenario.title}. ${scenario.subtitle}',
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(scenario.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                    Text(scenario.subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textDim)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(cameraServiceProvider).controller;
    if (ctrl == null || !ctrl.value.isInitialized) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(height: 180, width: double.infinity, child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: ctrl.value.previewSize?.height ?? 1, height: ctrl.value.previewSize?.width ?? 1, child: CameraPreview(ctrl)))),
        ),
      ),
    );
  }
}
