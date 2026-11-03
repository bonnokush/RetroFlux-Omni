import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/worker_isolate.dart';
import '../palette_switcher.dart';
import '../dashboard_screen.dart';

/// Dedicated Conversion History View
/// Pixel Native Material 3 + Material You Design
class HistoryView extends ConsumerWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskQueueProvider);
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_rounded, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conversion History & Outputs',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${completedTasks.length} file(s) converted successfully in this session',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Material You Palette',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: Icon(Icons.palette_outlined, color: colorScheme.primary, size: 20),
                  onPressed: () => PaletteSwitcherSheet.show(context),
                ),
                if (completedTasks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear History', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      for (final task in completedTasks) {
                        ref.read(taskQueueProvider.notifier).removeTask(task.id);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: completedTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.history_toggle_off, size: 40, color: colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No completed conversions yet',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Files you convert in Universal Batch or Studios will appear here',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: completedTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final task = completedTasks[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded, color: colorScheme.onSecondaryContainer, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.fileName,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colorScheme.onSurface),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Converted to ${task.targetFormat.toUpperCase()} • Saved to ${task.outputPath}',
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.folder_open_outlined, color: colorScheme.primary, size: 20),
                              tooltip: 'Open in Explorer',
                              onPressed: () {
                                if (Platform.isWindows) {
                                  Process.run('explorer.exe', ['/select,', task.outputPath]);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
