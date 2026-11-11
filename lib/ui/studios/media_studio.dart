import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../core/worker_isolate.dart';
import '../../core/license_service.dart';
import '../../core/engine_bridge.dart';
import '../pro_modal.dart';
import '../palette_switcher.dart';
import '../dashboard_screen.dart';

/// Dedicated 4K Video & Audio Media Studio
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
  bool _losslessRemux = false;
  String _detectedGpuLabel = 'Detecting GPU...';

  @override
  void initState() {
    super.initState();
    _probeGpu();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(licenseStateProvider) == LicenseTier.pro) {
        setState(() {
          _selectedResolution = '4K UHD (2160p)';
        });
      }
    });
  }

  Future<void> _probeGpu() async {
    final caps = await EngineBridge.detectGpuCapabilities();
    if (mounted) {
      setState(() {
        _detectedGpuLabel = caps.preferredVendorLabel;
      });
    }
  }

  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
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
        'wma',
      ],
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.whereType<String>().toList();
      await ref.read(taskQueueProvider.notifier).addFiles(validPaths);
    }
  }

  void _applyBatchFormat(String targetFormat) {
    final tasks = ref.read(taskQueueProvider);
    final mediaTasks =
        tasks.where((t) => t.category == TaskCategory.media).toList();
    for (final task in mediaTasks) {
      ref
          .read(taskQueueProvider.notifier)
          .updateTaskTarget(task.id, targetFormat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskQueueProvider);
    final mediaTasks =
        tasks.where((t) => t.category == TaskCategory.media).toList();
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
                _buildHeaderBanner(
                    context, isPro, mediaTasks.length, colorScheme),
                const SizedBox(height: 16),
                _buildSettingsDeck(context, isPro, colorScheme),
                const SizedBox(height: 16),
                if (mediaTasks.isEmpty)
                  Expanded(child: _buildEmptyDropZone(colorScheme))
                else ...[
                  _buildCompactDropZone(colorScheme),
                  const SizedBox(height: 16),
                  Expanded(
                      child:
                          _buildMediaQueueList(mediaTasks, isPro, colorScheme)),
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

  Widget _buildHeaderBanner(
      BuildContext context, bool isPro, int count, ColorScheme colorScheme) {
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
            child: Icon(Icons.video_camera_back,
                color: colorScheme.primary, size: 24),
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
                      '4K Video & Audio Media Studio',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPro
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isPro
                            ? '⚡ PRO 4K UHD UNLOCKED'
                            : 'FREE TIER (1080p CAP)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPro
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '⚡ $_detectedGpuLabel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hardware-accelerated 4K encoding, AV1/HEVC, instant lossless remux & audio extraction • $count file(s) in queue',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            icon: const Icon(Icons.video_call_outlined, size: 18),
            label: const Text(
              'Add Media Files',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.1),
            ),
            onPressed: _pickMediaFiles,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDeck(
      BuildContext context, bool isPro, ColorScheme colorScheme) {
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
          // Target Format Quick Chips
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Format: ',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant)),
              _buildTargetChip('MP4', 'mp4', colorScheme),
              _buildTargetChip('MKV', 'mkv', colorScheme),
              _buildTargetChip('MOV', 'mov', colorScheme),
              _buildTargetChip('WebM', 'webm', colorScheme),
              _buildTargetChip('MP3', 'mp3', colorScheme),
              _buildTargetChip('WAV', 'wav', colorScheme),
              _buildTargetChip('FLAC', 'flac', colorScheme),
            ],
          ),

          // Instant Lossless Remux Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _losslessRemux
                  ? colorScheme.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: _losslessRemux
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Lossless Remux (-c copy): ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _losslessRemux
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                Switch(
                  value: _losslessRemux,
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    setState(() => _losslessRemux = val);
                  },
                ),
              ],
            ),
          ),

          if (!_losslessRemux) ...[
            // Codec Dropdown
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Codec: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant)),
                DropdownButton<String>(
                  value: _selectedCodec,
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(
                      value: 'H.264 (Universal)',
                      child: Text('H.264 (Universal)'),
                    ),
                    DropdownMenuItem(
                      value: 'H.265 / HEVC',
                      child: Text(
                          isPro ? 'H.265 / HEVC' : 'H.265 / HEVC 🔒 PRO'),
                    ),
                    DropdownMenuItem(
                      value: 'AV1 Modern',
                      child:
                          Text(isPro ? 'AV1 Modern' : 'AV1 Modern 🔒 PRO'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      if ((val == 'H.265 / HEVC' || val == 'AV1 Modern') &&
                          !isPro) {
                        ProModal.show(context);
                      } else {
                        setState(() => _selectedCodec = val);
                      }
                    }
                  },
                ),
              ],
            ),

            // Resolution Dropdown (4K UHD first)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scale: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant)),
                DropdownButton<String>(
                  value: _selectedResolution,
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: '4K UHD (2160p)',
                      child: Text(
                          isPro ? '4K UHD (2160p)' : '4K UHD (2160p) 🔒 PRO'),
                    ),
                    DropdownMenuItem(
                      value: '1440p QHD',
                      child:
                          Text(isPro ? '1440p QHD' : '1440p QHD 🔒 PRO'),
                    ),
                    const DropdownMenuItem(
                      value: '1080p FHD',
                      child: Text('1080p FHD'),
                    ),
                    const DropdownMenuItem(
                      value: '720p HD',
                      child: Text('720p HD'),
                    ),
                    const DropdownMenuItem(
                      value: 'Original Source',
                      child: Text('Original Source'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      if ((val == '4K UHD (2160p)' || val == '1440p QHD') &&
                          !isPro) {
                        ProModal.show(context);
                      } else {
                        setState(() => _selectedResolution = val);
                      }
                    }
                  },
                ),
              ],
            ),

            // HW Acceleration Toggle
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GPU Accel: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant)),
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
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '⚡ Instant Container Remux: Swaps container in ~1 sec with zero re-encoding loss',
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDropZone(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.movie_creation_outlined,
                  color: colorScheme.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Drag & Drop 4K Videos or Audio Files Here',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'MP4, MKV, MOV, WebM, AVI, TS, MP3, FLAC, WAV • Hardware GPU Accelerated',
              style:
                  TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Browse Files',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _pickMediaFiles,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropZone(ColorScheme colorScheme) {
    return InkWell(
      onTap: _pickMediaFiles,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                color: colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Drop more media files or click to add',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaQueueList(
      List<ConversionTask> mediaTasks, bool isPro, ColorScheme colorScheme) {
    return ListView.separated(
      itemCount: mediaTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMediaTaskItem(mediaTasks[index], isPro, colorScheme);
      },
    );
  }

  Widget _buildMediaTaskItem(
      ConversionTask task, bool isPro, ColorScheme colorScheme) {
    final availableTargets = [
      'mp4',
      'mkv',
      'mov',
      'webm',
      'mp3',
      'wav',
      'flac',
      'aac'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Icon(Icons.movie_creation_outlined,
                    color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${task.targetFormat.toUpperCase()} ${task.statusDetail != null ? "• ${task.statusDetail}" : ""}',
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: ShapeDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  shape: const StadiumBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableTargets.contains(task.targetFormat)
                        ? task.targetFormat
                        : 'mp4',
                    dropdownColor: colorScheme.surfaceContainerHigh,
                    style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    items: availableTargets.map((target) {
                      return DropdownMenuItem(
                        value: target,
                        child: Text(target.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (newFormat) {
                      if (newFormat != null) {
                        ref
                            .read(taskQueueProvider.notifier)
                            .updateTaskTarget(task.id, newFormat);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: colorScheme.onSurfaceVariant),
                onPressed: () =>
                    ref.read(taskQueueProvider.notifier).removeTask(task.id),
              ),
            ],
          ),

          // Real-Time Progress & Telemetry UI
          if (task.status == TaskStatus.processing) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(task.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    if (task.fps != null)
                      Text('🎬 ${task.fps!.toStringAsFixed(0)} FPS',
                          style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant)),
                    if (task.speed != null)
                      Text('⚡ Speed: ${task.speed}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 5,
              ),
            ),
          ] else if (task.status == TaskStatus.completed) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  task.statusDetail ?? 'Completed',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.greenAccent),
                ),
              ],
            ),
          ] else if (task.status == TaskStatus.failed) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.errorMessage ?? 'Encoding failed',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.redAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(List<ConversionTask> mediaTasks,
      bool isProcessing, ColorScheme colorScheme) {
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
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant),
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
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colorScheme.onPrimaryContainer))
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              isProcessing ? 'Encoding...' : 'Convert All Media',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.1),
            ),
            onPressed: isProcessing || mediaTasks.isEmpty
                ? null
                : () {
                    ref.read(taskQueueProvider.notifier).startBatchConversion({
                      'codec': _selectedCodec,
                      'resolution': _selectedResolution,
                      'hwAccel': _hwAccel,
                      'losslessRemux': _losslessRemux,
                    });
                  },
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
              Icon(Icons.video_library_outlined,
                  color: colorScheme.primary, size: 54),
              const SizedBox(height: 14),
              Text(
                'DROP VIDEO & AUDIO FILES HERE',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
