import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../core/worker_isolate.dart';
import '../../core/license_service.dart';
import '../pro_modal.dart';
import '../palette_switcher.dart';
import '../dashboard_screen.dart';

/// Dedicated Microsoft Office & Document Conversion Studio
/// Pixel Native Material 3 + Material You Design
class DocsStudio extends ConsumerStatefulWidget {
  const DocsStudio({super.key});

  @override
  ConsumerState<DocsStudio> createState() => _DocsStudioState();
}

class _DocsStudioState extends ConsumerState<DocsStudio> {
  bool _isDragging = false;

  Future<void> _pickOfficeFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt',
        'pdf', 'txt', 'md', 'html', 'csv', 'json', 'rtf',
      ],
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.whereType<String>().toList();
      await ref.read(taskQueueProvider.notifier).addFiles(validPaths);
    }
  }

  void _applyBatchFormat(String targetFormat) {
    final tasks = ref.read(taskQueueProvider);
    final docTasks = tasks.where((t) => t.category == TaskCategory.document || t.category == TaskCategory.data).toList();
    for (final task in docTasks) {
      ref.read(taskQueueProvider.notifier).updateTaskTarget(task.id, targetFormat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskQueueProvider);
    final docTasks = tasks.where((t) => t.category == TaskCategory.document || t.category == TaskCategory.data).toList();
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
                _buildHeaderBanner(context, isPro, docTasks.length, colorScheme),
                const SizedBox(height: 16),
                _buildOfficePresetRow(colorScheme),
                const SizedBox(height: 16),
                if (docTasks.isEmpty)
                  Expanded(child: _buildEmptyDropZone(colorScheme))
                else ...[
                  _buildCompactDropZone(colorScheme),
                  const SizedBox(height: 16),
                  Expanded(child: _buildDocumentQueueList(docTasks, isPro, colorScheme)),
                ],
                const SizedBox(height: 16),
                _buildBottomActionBar(docTasks, isProcessing, colorScheme),
              ],
            ),
          ),
          if (_isDragging) _buildDragOverlay(colorScheme),
        ],
      ),
    );
  }

  /// Main Studio Card: Borderless card using colorScheme.surfaceContainer & BorderRadius.circular(28)
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
            child: Icon(Icons.description, color: colorScheme.primary, size: 24),
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
                      'Microsoft Office & Docs Studio',
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
                        isPro ? 'OFFICE PRO' : 'FREE TIER (MAX 3)',
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
                  'Convert Word (DOCX), Excel (XLSX), PowerPoint (PPTX), PDF, HTML & Markdown • $count document(s) in queue',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Live Material 3 Palette Switcher Icon
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
          // Native M3 FilledButton.icon using StadiumBorder(), primary fill & onPrimary text
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text(
              'Add Documents',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
            ),
            onPressed: _pickOfficeFiles,
          ),
        ],
      ),
    );
  }

  /// Responsive Non-Clipped Format Cards Row (Spec 5)
  Widget _buildOfficePresetRow(ColorScheme colorScheme) {
    final presets = [
      {'title': 'Word (.docx)', 'sub': '➔ PDF, MD, HTML', 'icon': Icons.article, 'target': 'pdf'},
      {'title': 'Excel (.xlsx)', 'sub': '➔ CSV, JSON, HTML', 'icon': Icons.table_chart, 'target': 'csv'},
      {'title': 'PowerPoint', 'sub': '➔ PDF Slides, HTML', 'icon': Icons.slideshow, 'target': 'pdf'},
      {'title': 'PDF Document', 'sub': '➔ Text, HTML, MD', 'icon': Icons.picture_as_pdf, 'target': 'txt'},
      {'title': 'Markdown / Text', 'sub': '➔ Word (.docx), PDF', 'icon': Icons.edit_note, 'target': 'docx'},
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final p = presets[idx];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _applyBatchFormat(p['target'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(p['icon'] as IconData, color: colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colorScheme.onSurface),
                      ),
                      Text(
                        p['sub'] as String,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Empty State Centered Inside Main Drop Zone Container (Spec 6)
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
                  child: Icon(Icons.file_upload_outlined, size: 40, color: colorScheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  'No documents in queue',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  'Drag and drop Microsoft Office files here or click "Add Documents"',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                // Cohesive M3 tonal pills using secondaryContainer with StadiumBorder() and zero outline
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildM3Chip('DOCX', colorScheme),
                    _buildM3Chip('XLSX', colorScheme),
                    _buildM3Chip('PPTX', colorScheme),
                    _buildM3Chip('PDF', colorScheme),
                    _buildM3Chip('TXT', colorScheme),
                    _buildM3Chip('CSV', colorScheme),
                    _buildM3Chip('JSON', colorScheme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact Drop Zone Banner when items are present
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
          Icon(Icons.file_download_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Drop more DOCX, XLSX, PPTX, or PDF files to add to queue',
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

  Widget _buildDocumentQueueList(List<ConversionTask> docTasks, bool isPro, ColorScheme colorScheme) {
    return ListView.separated(
      itemCount: docTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final task = docTasks[idx];
        return _buildDocTaskItem(task, isPro, colorScheme);
      },
    );
  }

  Widget _buildDocTaskItem(ConversionTask task, bool isPro, ColorScheme colorScheme) {
    final ext = task.fileName.split('.').last.toLowerCase();
    final availableTargets = _getTargetsForExtension(ext);

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
                child: Icon(Icons.description_outlined, color: colorScheme.primary, size: 20),
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
                    value: availableTargets.contains(task.targetFormat) ? task.targetFormat : availableTargets.first,
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

  List<String> _getTargetsForExtension(String ext) {
    switch (ext) {
      case 'docx':
      case 'doc':
        return ['pdf', 'html', 'md', 'txt'];
      case 'xlsx':
      case 'xls':
        return ['csv', 'json', 'html', 'pdf', 'txt'];
      case 'pptx':
      case 'ppt':
        return ['pdf', 'html', 'md', 'txt'];
      case 'pdf':
        return ['txt', 'html', 'md'];
      case 'md':
      case 'txt':
        return ['pdf', 'docx', 'html'];
      case 'csv':
        return ['xlsx', 'json', 'pdf', 'html'];
      case 'json':
        return ['csv', 'xlsx', 'pdf'];
      default:
        return ['pdf', 'txt', 'html'];
    }
  }

  /// Bottom Action Bar: Borderless card using colorScheme.surfaceContainer & BorderRadius.circular(28)
  Widget _buildBottomActionBar(List<ConversionTask> docTasks, bool isProcessing, ColorScheme colorScheme) {
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
            '${docTasks.length} document(s) in queue',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: docTasks.isEmpty
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : colorScheme.primaryContainer,
              foregroundColor: docTasks.isEmpty
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimaryContainer,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            ),
            icon: isProcessing
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimaryContainer))
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              isProcessing ? 'Converting...' : 'Convert All Documents',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
            ),
            onPressed: isProcessing || docTasks.isEmpty
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
              Icon(Icons.file_download_outlined, color: colorScheme.primary, size: 54),
              const SizedBox(height: 14),
              Text(
                'DROP OFFICE & DOCUMENT FILES HERE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
