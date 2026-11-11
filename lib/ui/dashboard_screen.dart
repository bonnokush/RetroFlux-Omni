import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../core/engine_bridge.dart';
import '../core/worker_isolate.dart';
import '../core/license_service.dart';
import 'pro_modal.dart';
import 'palette_switcher.dart';

/// Engine Bridge Provider
final engineBridgeProvider = Provider<EngineBridge>((ref) {
  final license = ref.watch(licenseServiceProvider);
  return EngineBridge(licenseService: license);
});

/// Task Queue Provider
final taskQueueProvider =
    StateNotifierProvider<TaskQueueNotifier, List<ConversionTask>>((ref) {
  final bridge = ref.watch(engineBridgeProvider);
  return TaskQueueNotifier(bridge, ref);
});

class TaskQueueNotifier extends StateNotifier<List<ConversionTask>> {
  final EngineBridge _bridge;
  final Ref _ref;

  TaskQueueNotifier(this._bridge, this._ref) : super([]);

  Future<void> addFiles(List<String> paths) async {
    final currentCount = state.length;
    final isPro = _ref.read(licenseStateProvider) == LicenseTier.pro;
    final maxLimit = isPro ? 1000 : 3;

    final availableSlots = maxLimit - currentCount;
    if (availableSlots <= 0) {
      return;
    }

    final allowedPaths = paths.take(availableSlots).toList();
    final newTasks = allowedPaths.map((p) {
      final ext = p.split('.').last.toLowerCase();
      final cat = _categorizeExtension(ext);
      final defaultTarget = _defaultTargetForCategory(cat, ext);
      final outPath = _computeOutputPath(p, defaultTarget);

      return ConversionTask(
        id: '${DateTime.now().millisecondsSinceEpoch}_${p.hashCode}',
        inputPath: p,
        outputPath: outPath,
        targetFormat: defaultTarget,
        category: cat,
      );
    }).toList();

    state = [...state, ...newTasks];
  }

  void updateTargetFormat(String taskId, String newFormat) {
    state = [
      for (final task in state)
        if (task.id == taskId)
          ConversionTask(
            id: task.id,
            inputPath: task.inputPath,
            outputPath: _computeOutputPath(task.inputPath, newFormat),
            targetFormat: newFormat,
            category: task.category,
            options: task.options,
            fileSizeBytes: task.fileSizeBytes,
            createdAt: task.createdAt,
            status: task.status,
            progress: task.progress,
            duration: task.duration,
            speed: task.speed,
            fps: task.fps,
            statusDetail: task.statusDetail,
          )
        else
          task
    ];
  }

  void updateTaskTarget(String taskId, String newFormat) =>
      updateTargetFormat(taskId, newFormat);

  void updateTaskOptions(String taskId, Map<String, dynamic> newOptions) {
    state = [
      for (final task in state)
        if (task.id == taskId)
          ConversionTask(
            id: task.id,
            inputPath: task.inputPath,
            outputPath: task.outputPath,
            targetFormat: task.targetFormat,
            category: task.category,
            options: {...task.options, ...newOptions},
            fileSizeBytes: task.fileSizeBytes,
            createdAt: task.createdAt,
            status: task.status,
            progress: task.progress,
            duration: task.duration,
            speed: task.speed,
            fps: task.fps,
            statusDetail: task.statusDetail,
          )
        else
          task
    ];
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void clearQueue() {
    state = [];
  }

  Future<void> startBatchConversion(
      [Map<String, dynamic>? globalOptions]) async {
    for (final task in state) {
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.processing) {
        continue;
      }

      if (globalOptions != null) {
        task.options.addAll(globalOptions);
      }

      task.status = TaskStatus.processing;
      state = [...state];

      try {
        await _bridge.executeTask(task, onProgress: (p) {
          task.progress = p;
          state = [...state];
        });
        task.status = TaskStatus.completed;
      } catch (e) {
        task.status = TaskStatus.failed;
        task.errorMessage = e.toString();
      }
      state = [...state];
    }
  }

  TaskCategory _categorizeExtension(String ext) {
    if ([
      'mp4',
      'mkv',
      'mov',
      'avi',
      'webm',
      'flv',
      'wmv',
      'ts',
      'm4v',
      'mp3',
      'wav',
      'aac',
      'flac',
      'm4a',
      'ogg',
      'opus',
      'wma'
    ].contains(ext)) {
      return TaskCategory.media;
    }
    return TaskCategory.image;
  }

  String _defaultTargetForCategory(TaskCategory cat, String sourceExt) {
    switch (cat) {
      case TaskCategory.image:
        return sourceExt == 'png' ? 'jpg' : 'png';
      case TaskCategory.media:
        final isAudio = [
          'mp3',
          'wav',
          'aac',
          'flac',
          'm4a',
          'ogg',
          'opus',
          'wma'
        ].contains(sourceExt);
        if (isAudio) return sourceExt == 'mp3' ? 'wav' : 'mp3';
        return sourceExt == 'mp4' ? 'mkv' : 'mp4';
      case TaskCategory.data:
      case TaskCategory.document:
        return 'txt';
    }
  }

  String _computeOutputPath(String input, String targetExt) {
    final lastDot = input.lastIndexOf('.');
    final prefix = lastDot != -1 ? input.substring(0, lastDot) : input;
    return '${prefix}_converted.$targetExt';
  }
}

/// Universal Drop Zone & Batch Queue Dashboard Screen
/// Pixel Native Material 3 + Material You Design
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isDragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.whereType<String>().toList();
      await ref.read(taskQueueProvider.notifier).addFiles(validPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskQueueProvider);
    final license = ref.watch(licenseStateProvider);
    final isPro = license == LicenseTier.pro;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final padding = isCompact ? 12.0 : 24.0;

        return DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) async {
            setState(() => _isDragging = false);
            final paths = details.files.map((f) => f.path).toList();
            await ref.read(taskQueueProvider.notifier).addFiles(paths);
          },
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Status Banner: M3 Borderless Card (BorderRadius.circular(28))
                    _buildHeaderBanner(
                        context, isPro, tasks.length, colorScheme),
                    const SizedBox(height: 12),

                    // Conversion Tasks Table / Centered Drop Zone
                    Expanded(
                      child: tasks.isEmpty
                          ? _buildEmptyState(colorScheme)
                          : ListView.separated(
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                return _TaskCard(task: task);
                              },
                            ),
                    ),

                    // Bottom Action Bar: M3 Borderless Card (BorderRadius.circular(28))
                    const SizedBox(height: 12),
                    _buildBottomBar(tasks, colorScheme),
                  ],
                ),
              ),

              // Drag Over Visual Layer
              if (_isDragging)
                Container(
                  color: colorScheme.surface.withOpacity(0.9),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_outlined,
                              color: colorScheme.primary, size: 56),
                          const SizedBox(height: 16),
                          Text(
                            'DROP FILES HERE TO ENQUEUE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isPro, int queueCount,
      ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  'Universal Conversion Engine',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPro
                        ? colorScheme.secondaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isPro ? 'PRO UNLIMITED' : 'FREE TIER (MAX 3)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPro
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Media, Images, Documents, and Data • Queue: $queueCount items',
              style:
                  TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Material You Palette',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.all(12),
              ),
              icon: Icon(Icons.palette_outlined,
                  color: colorScheme.primary, size: 20),
              onPressed: () => PaletteSwitcherSheet.show(context),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Files',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              onPressed: _pickFiles,
            ),
          ],
        );

        final isCompact = constraints.maxWidth < 620;

        if (isCompact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: content),
                  ],
                ),
                const SizedBox(height: 12),
                actionButtons,
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: content),
              const SizedBox(width: 12),
              actionButtons,
            ],
          ),
        );
      },
    );
  }

  /// Empty State Centered Inside Main Drop Zone Container (Spec 6)
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.file_upload_outlined,
                      size: 30, color: colorScheme.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  'Queue is empty',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Drag and drop files here or click "Add Files" above',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildM3Chip('MP4 / Video', colorScheme),
                    _buildM3Chip('DOCX / Office', colorScheme),
                    _buildM3Chip('PNG / Images', colorScheme),
                    _buildM3Chip('PDF / Docs', colorScheme),
                    _buildM3Chip('XLSX / Data', colorScheme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildM3Chip(String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: ShapeDecoration(
        color: colorScheme.secondaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<ConversionTask> tasks, ColorScheme colorScheme) {
    final hasProcessing = tasks.any((t) => t.status == TaskStatus.processing);
    final hasQueued = tasks.any((t) => t.status == TaskStatus.queued);

    final clearBtn = TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.error,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: const Icon(Icons.clear_all, size: 18),
      label: const Text('Clear Queue'),
      onPressed: tasks.isEmpty || hasProcessing
          ? null
          : () => ref.read(taskQueueProvider.notifier).clearQueue(),
    );

    final convertBtn = FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: (!hasQueued || hasProcessing)
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : colorScheme.primaryContainer,
        foregroundColor: (!hasQueued || hasProcessing)
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimaryContainer,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      ),
      icon: hasProcessing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colorScheme.onPrimaryContainer))
          : const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(
        hasProcessing ? 'CONVERTING...' : 'START BATCH CONVERSION',
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
      ),
      onPressed: !hasQueued || hasProcessing
          ? null
          : () => ref.read(taskQueueProvider.notifier).startBatchConversion(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 550;
        if (isCompact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                convertBtn,
                const SizedBox(height: 6),
                Center(child: clearBtn),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              clearBtn,
              convertBtn,
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final ConversionTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskQueueProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildCategoryIcon(task.category, task.fileName, colorScheme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(task.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB • Path: ${task.inputPath}',
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Target Format Selector
              _buildFormatDropdown(task, notifier, colorScheme),

              const SizedBox(width: 12),
              _buildStatusWidget(task, colorScheme),

              IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: colorScheme.onSurfaceVariant),
                onPressed: task.status == TaskStatus.processing
                    ? null
                    : () => notifier.removeTask(task.id),
              ),
            ],
          ),

          // Linear Progress Bar
          if (task.status == TaskStatus.processing) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(
      TaskCategory cat, String fileName, ColorScheme colorScheme) {
    IconData icon;
    final ext = fileName.split('.').last.toLowerCase();

    if (['docx', 'doc'].contains(ext)) {
      icon = Icons.article;
    } else if (['xlsx', 'xls'].contains(ext)) {
      icon = Icons.table_chart;
    } else if (['pptx', 'ppt'].contains(ext)) {
      icon = Icons.slideshow;
    } else if (ext == 'pdf') {
      icon = Icons.picture_as_pdf;
    } else {
      switch (cat) {
        case TaskCategory.image:
          icon = Icons.image_outlined;
          break;
        case TaskCategory.media:
          icon = Icons.movie_filter_outlined;
          break;
        case TaskCategory.data:
          icon = Icons.data_object;
          break;
        case TaskCategory.document:
          icon = Icons.description_outlined;
          break;
      }
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colorScheme.primary, size: 20),
    );
  }

  Widget _buildFormatDropdown(ConversionTask task, TaskQueueNotifier notifier,
      ColorScheme colorScheme) {
    List<String> options = [];
    final ext = task.fileName.split('.').last.toLowerCase();

    if (['docx', 'doc'].contains(ext)) {
      options = ['pdf', 'html', 'md', 'txt'];
    } else if (['xlsx', 'xls'].contains(ext)) {
      options = ['csv', 'json', 'html', 'pdf', 'txt'];
    } else if (['pptx', 'ppt'].contains(ext)) {
      options = ['pdf', 'html', 'md', 'txt'];
    } else if (ext == 'pdf') {
      options = ['txt', 'html', 'md'];
    } else {
      switch (task.category) {
        case TaskCategory.image:
          options = ['webp', 'png', 'jpg', 'bmp', 'ico', 'gif'];
          break;
        case TaskCategory.media:
          options = [
            'mp4',
            'mkv',
            'mov',
            'webm',
            'mp3',
            'wav',
            'aac',
            'flac',
            'gif'
          ];
          break;
        case TaskCategory.data:
          options = ['json', 'csv', 'xlsx', 'pdf'];
          break;
        case TaskCategory.document:
          options = ['pdf', 'docx', 'html', 'txt', 'md'];
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(task.targetFormat)
              ? task.targetFormat
              : options.first,
          dropdownColor: colorScheme.surfaceContainerHigh,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary),
          items: options
              .map((f) =>
                  DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
              .toList(),
          onChanged: task.status == TaskStatus.processing
              ? null
              : (newVal) {
                  if (newVal != null) {
                    notifier.updateTargetFormat(task.id, newVal);
                  }
                },
        ),
      ),
    );
  }

  Widget _buildStatusWidget(ConversionTask task, ColorScheme colorScheme) {
    switch (task.status) {
      case TaskStatus.queued:
        return Text('Queued',
            style:
                TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12));
      case TaskStatus.processing:
        return Text('${(task.progress * 100).toInt()}%',
            style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold));
      case TaskStatus.completed:
        return Icon(Icons.check_circle_outline,
            color: colorScheme.primary, size: 20);
      case TaskStatus.failed:
        return Tooltip(
          message: 'Conversion error',
          child: Icon(Icons.error_outline, color: colorScheme.error, size: 20),
        );
    }
  }
}
