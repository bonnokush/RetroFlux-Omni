import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../core/worker_isolate.dart';
import '../../core/license_service.dart';
import '../pro_modal.dart';
import '../palette_switcher.dart';
import '../dashboard_screen.dart';

/// Dedicated Video & Audio Media Studio
/// Pixel Native Material 3 + Material You Design
class MediaStudio extends ConsumerStatefulWidget {
  const MediaStudio({super.key});

  @override
  ConsumerState<MediaStudio> createState() => _MediaStudioState();
}

class _MediaStudioState extends ConsumerState<MediaStudio> {
  bool _isDragging = false;
  String _selectedCodec = 'H.264 (Universal)';
  String _selectedResolution = '1080p FHD';
  bool _hwAccel = true;

  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', 'wmv',
        'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'wma',
      ],
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.whereType<String>().toList();
      await ref.read(taskQueueProvider.notifier).addFiles(validPaths);
    }
  }

  void _applyBatchFormat(String targetFormat) {
    final tasks = ref.read(taskQueueProvider);
    final mediaTasks = tasks.where((t) => t.category == TaskCategory.media).toList();
    for (final task in mediaTasks) {
      ref.read(taskQueueProvider.notifier).updateTaskTarget(task.id, targetFormat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskQueueProvider);
    final mediaTasks = tasks.where((t) => t.category == TaskCategory.media).toList();
    final isPro = ref.watch(licenseStateProvider) == LicenseTier.pro;
    final isProcessing = tasks.any((t) => t.status == TaskStatus.processing);
    final colorScheme = Theme.of(context).colorScheme;

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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(context, isPro, mediaTasks.length, colorScheme),
                const SizedBox(height: 16),
                _buildSettingsDeck(context, isPro, colorScheme),
                const SizedBox(height: 16),
                if (mediaTasks.isEmpty)
                  Expanded(child: _buildEmptyDropZone(colorScheme))
                else ...[
                  _buildCompactDropZone(colorScheme),
                  const SizedBox(height: 16),
                  Expanded(child: _buildMediaQueueList(mediaTasks, isPro, colorScheme)),
                ],
                const SizedBox(height: 16),
                _buildBottomActionBar(mediaTasks, isProcessing, colorScheme),
              ],
            ),
          ),
          if (_isDragging) _buildDragOverlay(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isPro, int count, ColorScheme colorScheme) {
    return Container(
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
            child: Icon(Icons.video_camera_back, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Video & Audio Media Studio',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPro ? colorScheme.secondaryContainer : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isPro ? 'FFMPEG PRO' : 'FREE TIER (1080p CAP)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPro ? colorScheme.onSecondaryContainer : colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hardware-accelerated encoding, AV1/HEVC, and audio extraction • $count media file(s) in queue',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Material You Palette',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.all(12),
            ),
            icon: Icon(Icons.palette_outlined, color: colorScheme.primary, size: 20),
            onPressed: () => PaletteSwitcherSheet.show(context),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            icon: const Icon(Icons.video_call_outlined, size: 18),
            label: const Text(
              'Add Media Files',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
            ),
            onPressed: _pickMediaFiles,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDeck(BuildContext context, bool isPro, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Format: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
              _buildTargetChip('MP4', 'mp4', colorScheme),
              _buildTargetChip('MKV', 'mkv', colorScheme),
              _buildTargetChip('MOV', 'mov', colorScheme),
              _buildTargetChip('WebM', 'webm', colorScheme),
              _buildTargetChip('MP3', 'mp3', colorScheme),
              _buildTargetChip('WAV', 'wav', colorScheme),
              _buildTargetChip('GIF', 'gif', colorScheme),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Codec: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
              DropdownButton<String>(
                value: _selectedCodec,
                dropdownColor: colorScheme.surfaceContainerHigh,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                underline: const SizedBox(),
                items: [
                  'H.264 (Universal)',
                  'H.265 / HEVC ${isPro ? "" : "🔒 PRO"}',
                  'AV1 Modern ${isPro ? "" : "🔒 PRO"}',
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    if (val.contains('PRO') && !isPro) {
                      ProModal.show(context);
                    } else {
                      setState(() => _selectedCodec = val);
                    }
                  }
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scale: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
              DropdownButton<String>(
                value: _selectedResolution,
                dropdownColor: colorScheme.surfaceContainerHigh,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                underline: const SizedBox(),
                items: [
                  'Original Source',
                  '1080p FHD',
                  '720p HD',
                  '4K UHD ${isPro ? "" : "🔒 PRO"}',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    if (val.contains('PRO') && !isPro) {
                      ProModal.show(context);
                    } else {
                      setState(() => _selectedResolution = val);
                    }
                  }
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('HW Accel: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
              Switch(
                value: _hwAccel,
                activeColor: colorScheme.primary,
                onChanged: (val) {
                  if (!isPro) {
                    ProModal.show(context);
                  } else {
                    setState(() => _hwAccel = val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String label, String ext, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _applyBatchFormat(ext),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: ShapeDecoration(
            color: colorScheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDropZone(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                  child: Icon(Icons.movie_outlined, size: 40, color: colorScheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  'No media files in queue',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  'Drop video or audio files here to transcode or extract audio',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildM3Chip('MP4', colorScheme),
                    _buildM3Chip('MKV', colorScheme),
                    _buildM3Chip('MOV', colorScheme),
                    _buildM3Chip('WebM', colorScheme),
                    _buildM3Chip('MP3', colorScheme),
                    _buildM3Chip('WAV', colorScheme),
                    _buildM3Chip('FLAC', colorScheme),
                    _buildM3Chip('AAC', colorScheme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDropZone(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Drop more video or audio files to add to queue',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
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

  Widget _buildMediaQueueList(List<ConversionTask> mediaTasks, bool isPro, ColorScheme colorScheme) {
    return ListView.separated(
      itemCount: mediaTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final task = mediaTasks[idx];
        return _buildMediaTaskItem(task, isPro, colorScheme);
      },
    );
  }

  Widget _buildMediaTaskItem(ConversionTask task, bool isPro, ColorScheme colorScheme) {
    final availableTargets = ['mp4', 'mkv', 'mov', 'webm', 'mp3', 'wav', 'aac', 'flac', 'gif'];

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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.movie_creation_outlined, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target format: ${task.targetFormat.toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: ShapeDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  shape: const StadiumBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableTargets.contains(task.targetFormat) ? task.targetFormat : 'mp4',
                    dropdownColor: colorScheme.surfaceContainerHigh,
                    style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    items: availableTargets.map((target) {
                      return DropdownMenuItem(
                        value: target,
                        child: Text(target.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (newFormat) {
                      if (newFormat != null) {
                        ref.read(taskQueueProvider.notifier).updateTaskTarget(task.id, newFormat);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
                onPressed: () => ref.read(taskQueueProvider.notifier).removeTask(task.id),
              ),
            ],
          ),
          if (task.status == TaskStatus.processing) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(List<ConversionTask> mediaTasks, bool isProcessing, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${mediaTasks.length} media file(s) in queue',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: mediaTasks.isEmpty
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : colorScheme.primaryContainer,
              foregroundColor: mediaTasks.isEmpty
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimaryContainer,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            ),
            icon: isProcessing
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimaryContainer))
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              isProcessing ? 'Encoding...' : 'Convert All Media',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
            ),
            onPressed: isProcessing || mediaTasks.isEmpty
                ? null
                : () => ref.read(taskQueueProvider.notifier).startBatchConversion(),
          ),
        ],
      ),
    );
  }

  Widget _buildDragOverlay(ColorScheme colorScheme) {
    return Container(
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
              Icon(Icons.video_library_outlined, color: colorScheme.primary, size: 54),
              const SizedBox(height: 14),
              Text(
                'DROP VIDEO & AUDIO FILES HERE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
