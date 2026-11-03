import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../core/worker_isolate.dart';
import '../../core/license_service.dart';
import '../pro_modal.dart';
import '../palette_switcher.dart';
import '../dashboard_screen.dart';

/// Dedicated Image Studio & Compressor
/// Pixel Native Material 3 + Material You Design
class ImageStudio extends ConsumerStatefulWidget {
  const ImageStudio({super.key});

  @override
  ConsumerState<ImageStudio> createState() => _ImageStudioState();
}

class _ImageStudioState extends ConsumerState<ImageStudio> {
  bool _isDragging = false;
  double _quality = 85.0;
  String _selectedScale = 'Original (100%)';

  Future<void> _pickImageFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'tga', 'gif', 'ico', 'tiff'],
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.whereType<String>().toList();
      await ref.read(taskQueueProvider.notifier).addFiles(validPaths);
    }
  }

  void _applyBatchFormat(String targetFormat) {
    final tasks = ref.read(taskQueueProvider);
    final imageTasks = tasks.where((t) => t.category == TaskCategory.image).toList();
    for (final task in imageTasks) {
      ref.read(taskQueueProvider.notifier).updateTaskTarget(task.id, targetFormat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskQueueProvider);
    final imageTasks = tasks.where((t) => t.category == TaskCategory.image).toList();
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
                _buildHeaderBanner(context, isPro, imageTasks.length, colorScheme),
                const SizedBox(height: 16),
                _buildSettingsDeck(colorScheme),
                const SizedBox(height: 16),
                if (imageTasks.isEmpty)
                  Expanded(child: _buildEmptyDropZone(colorScheme))
                else ...[
                  _buildCompactDropZone(colorScheme),
                  const SizedBox(height: 16),
                  Expanded(child: _buildImageQueueList(imageTasks, isPro, colorScheme)),
                ],
                const SizedBox(height: 16),
                _buildBottomActionBar(imageTasks, isProcessing, colorScheme),
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
            child: Icon(Icons.image, color: colorScheme.primary, size: 24),
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
                      'Image Studio & Compressor',
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
                        isPro ? 'IMAGE PRO' : 'FREE TIER (MAX 3)',
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
                  'Multi-threaded isolate workers, WebP lossless, and photo compression • $count image(s) in queue',
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
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text(
              'Add Images',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
            ),
            onPressed: _pickImageFiles,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDeck(ColorScheme colorScheme) {
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
              _buildTargetChip('WebP', 'webp', colorScheme),
              _buildTargetChip('PNG', 'png', colorScheme),
              _buildTargetChip('JPG', 'jpg', colorScheme),
              _buildTargetChip('BMP', 'bmp', colorScheme),
              _buildTargetChip('ICO', 'ico', colorScheme),
              _buildTargetChip('GIF', 'gif', colorScheme),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quality (${_quality.round()}%): ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
              SizedBox(
                width: 120,
                child: Slider(
                  value: _quality,
                  min: 10,
                  max: 100,
                  activeColor: colorScheme.primary,
                  onChanged: (val) => setState(() => _quality = val),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scale: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
              DropdownButton<String>(
                value: _selectedScale,
                dropdownColor: colorScheme.surfaceContainerHigh,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                underline: const SizedBox(),
                items: [
                  'Original (100%)',
                  '75% Scale',
                  '50% Half-Scale',
                  '25% Thumbnail',
                ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedScale = val);
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
                  child: Icon(Icons.image_outlined, size: 40, color: colorScheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  'No images in queue',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  'Drop PNG, JPG, or WebP images to optimize and convert',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildM3Chip('PNG', colorScheme),
                    _buildM3Chip('JPG', colorScheme),
                    _buildM3Chip('WEBP', colorScheme),
                    _buildM3Chip('BMP', colorScheme),
                    _buildM3Chip('ICO', colorScheme),
                    _buildM3Chip('TIFF', colorScheme),
                    _buildM3Chip('GIF', colorScheme),
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
          Icon(Icons.photo_library_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Drop more PNG, JPG, or WebP images to add to queue',
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

  Widget _buildImageQueueList(List<ConversionTask> imageTasks, bool isPro, ColorScheme colorScheme) {
    return ListView.separated(
      itemCount: imageTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final task = imageTasks[idx];
        return _buildImageTaskItem(task, isPro, colorScheme);
      },
    );
  }

  Widget _buildImageTaskItem(ConversionTask task, bool isPro, ColorScheme colorScheme) {
    final availableTargets = ['webp', 'png', 'jpg', 'bmp', 'ico', 'gif'];

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
                child: Icon(Icons.image, color: colorScheme.primary, size: 20),
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
                    value: availableTargets.contains(task.targetFormat) ? task.targetFormat : 'webp',
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

  Widget _buildBottomActionBar(List<ConversionTask> imageTasks, bool isProcessing, ColorScheme colorScheme) {
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
            '${imageTasks.length} image(s) in queue',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: imageTasks.isEmpty
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : colorScheme.primaryContainer,
              foregroundColor: imageTasks.isEmpty
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimaryContainer,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            ),
            icon: isProcessing
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimaryContainer))
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              isProcessing ? 'Optimizing...' : 'Convert All Images',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
            ),
            onPressed: isProcessing || imageTasks.isEmpty
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
              Icon(Icons.photo_library_outlined, color: colorScheme.primary, size: 54),
              const SizedBox(height: 14),
              Text(
                'DROP IMAGE FILES HERE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
