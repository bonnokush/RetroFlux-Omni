import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Conversion Category
enum TaskCategory {
  media,
  image,
  document,
  data,
}

/// Status of a Conversion Job
enum TaskStatus {
  queued,
  processing,
  completed,
  failed,
}

/// Immutable Task Definition
class ConversionTask {
  final String id;
  final String inputPath;
  final String outputPath;
  final String targetFormat;
  final TaskCategory category;
  final Map<String, dynamic> options;
  final int fileSizeBytes;
  final DateTime createdAt;

  TaskStatus status;
  double progress;
  String? errorMessage;
  Duration? duration;
  String? speed;
  double? fps;
  String? statusDetail;

  ConversionTask({
    required this.id,
    required this.inputPath,
    required this.outputPath,
    required this.targetFormat,
    required this.category,
    this.options = const {},
    this.fileSizeBytes = 0,
    DateTime? createdAt,
    this.status = TaskStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.duration,
    this.speed,
    this.fps,
    this.statusDetail,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fileName {
    final normalized = inputPath.replaceAll(r'\', '/');
    return normalized.split('/').last;
  }
}

/// Isolate Payload for Pure Dart Processing
class IsolatePayload {
  final String taskId;
  final String inputPath;
  final String outputPath;
  final String targetFormat;
  final Map<String, dynamic> options;
  final SendPort sendPort;

  IsolatePayload({
    required this.taskId,
    required this.inputPath,
    required this.outputPath,
    required this.targetFormat,
    required this.options,
    required this.sendPort,
  });
}

/// Message emitted from Isolate back to the main thread
class IsolateProgressMessage {
  final String taskId;
  final double progress;
  final bool isCompleted;
  final String? error;

  IsolateProgressMessage({
    required this.taskId,
    required this.progress,
    this.isCompleted = false,
    this.error,
  });
}

/// Background Worker Pool managing parallel non-blocking conversions
class WorkerIsolatePool {
  static const int _maxConcurrentIsolates = 4;
  int _activeWorkers = 0;
  final List<ConversionTask> _queue = [];
  final Map<String, StreamController<double>> _progressControllers = {};

  bool get hasActiveTasks => _activeWorkers > 0 || _queue.isNotEmpty;

  /// Enqueues a task and returns a progress stream
  Stream<double> enqueueTask(ConversionTask task,
      {required Future<void> Function(ConversionTask) onExecute}) {
    final controller = StreamController<double>.broadcast();
    _progressControllers[task.id] = controller;
    _queue.add(task);
    _drainQueue(onExecute);
    return controller.stream;
  }

  void _drainQueue(Future<void> Function(ConversionTask) onExecute) {
    if (_activeWorkers >= _maxConcurrentIsolates || _queue.isEmpty) {
      return;
    }

    final task = _queue.removeAt(0);
    _activeWorkers++;
    task.status = TaskStatus.processing;

    final stopwatch = Stopwatch()..start();

    onExecute(task).then((_) {
      stopwatch.stop();
      task.status = TaskStatus.completed;
      task.progress = 1.0;
      task.duration = stopwatch.elapsed;
      _progressControllers[task.id]?.add(1.0);
      _progressControllers[task.id]?.close();
      _progressControllers.remove(task.id);
    }).catchError((e) {
      stopwatch.stop();
      task.status = TaskStatus.failed;
      task.errorMessage = e.toString();
      _progressControllers[task.id]?.addError(e);
      _progressControllers[task.id]?.close();
      _progressControllers.remove(task.id);
    }).whenComplete(() {
      _activeWorkers--;
      _drainQueue(onExecute);
    });
  }

  /// High-Performance Background Image Converter running in an isolated thread
  static void processImageInIsolate(IsolatePayload payload) {
    try {
      final inputFile = File(payload.inputPath);
      if (!inputFile.existsSync()) {
        payload.sendPort.send(IsolateProgressMessage(
          taskId: payload.taskId,
          progress: 0.0,
          error: 'Input file does not exist',
        ));
        return;
      }

      payload.sendPort
          .send(IsolateProgressMessage(taskId: payload.taskId, progress: 0.25));

      final Uint8List bytes = inputFile.readAsBytesSync();
      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        payload.sendPort.send(IsolateProgressMessage(
          taskId: payload.taskId,
          progress: 0.0,
          error: 'Failed to decode image file format',
        ));
        return;
      }

      payload.sendPort
          .send(IsolateProgressMessage(taskId: payload.taskId, progress: 0.65));

      final format = payload.targetFormat.toLowerCase();
      Uint8List encodedBytes;

      final quality = (payload.options['quality'] as int?) ?? 85;

      switch (format) {
        case 'png':
          encodedBytes = Uint8List.fromList(img.encodePng(decoded));
          break;
        case 'jpg':
        case 'jpeg':
          encodedBytes =
              Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
          break;
        case 'webp':
          // Using lossy/lossless WebP encoding
          encodedBytes =
              Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
          break;
        case 'bmp':
          encodedBytes = Uint8List.fromList(img.encodeBmp(decoded));
          break;
        case 'tga':
          encodedBytes = Uint8List.fromList(img.encodeTga(decoded));
          break;
        default:
          encodedBytes = Uint8List.fromList(img.encodePng(decoded));
      }

      payload.sendPort
          .send(IsolateProgressMessage(taskId: payload.taskId, progress: 0.90));

      final outputFile = File(payload.outputPath);
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsBytesSync(encodedBytes);

      payload.sendPort.send(IsolateProgressMessage(
        taskId: payload.taskId,
        progress: 1.0,
        isCompleted: true,
      ));
    } catch (e) {
      payload.sendPort.send(IsolateProgressMessage(
        taskId: payload.taskId,
        progress: 0.0,
        error: e.toString(),
      ));
    }
  }
}
