import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/event_tile.dart';
import '../awareness/awareness_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(awarenessProvider.select((s) => s.history));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event history'),
        actions: [
          if (h.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(awarenessProvider.notifier).clearHistory(),
            ),
        ],
      ),
      body: SafeArea(
        child: h.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No events yet. Important events will appear here.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: AppColors.textDim)),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: h.length,
                itemBuilder: (_, i) => EventTile(alert: h[i]),
              ),
      ),
    );
  }
}
