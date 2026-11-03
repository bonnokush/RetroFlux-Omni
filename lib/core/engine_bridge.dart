import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'worker_isolate.dart';
import 'license_service.dart';
import 'office_engine.dart';

/// Universal File Conversion Bridge
/// Abstracting Native FFmpeg, C++ native image processing, and Document/Data formats
class EngineBridge {
  final LicenseService licenseService;
  final WorkerIsolatePool workerPool;

  EngineBridge({
    required this.licenseService,
    WorkerIsolatePool? workerPool,
  }) : workerPool = workerPool ?? WorkerIsolatePool();

  /// Converts a single task using the optimal platform engine
  Future<void> executeTask(ConversionTask task, {void Function(double progress)? onProgress}) async {
    switch (task.category) {
      case TaskCategory.image:
        await _executeImageConversion(task, onProgress);
        break;
      case TaskCategory.media:
        await _executeMediaConversion(task, onProgress);
        break;
      case TaskCategory.data:
        await _executeDataConversion(task, onProgress);
        break;
      case TaskCategory.document:
        await _executeDocumentConversion(task, onProgress);
        break;
    }
  }

  // --- Image Processing (Isolate worker) ---

  Future<void> _executeImageConversion(ConversionTask task, void Function(double progress)? onProgress) async {
    final receivePort = ReceivePort();
    final completer = Completer<void>();

    final payload = IsolatePayload(
      taskId: task.id,
      inputPath: task.inputPath,
      outputPath: task.outputPath,
      targetFormat: task.targetFormat,
      options: task.options,
      sendPort: receivePort.sendPort,
    );

    await Isolate.spawn(WorkerIsolatePool.processImageInIsolate, payload);

    late StreamSubscription sub;
    sub = receivePort.listen((message) {
      if (message is IsolateProgressMessage) {
        onProgress?.call(message.progress);
        task.progress = message.progress;

        if (message.error != null) {
          sub.cancel();
          receivePort.close();
          completer.completeError(Exception(message.error));
        } else if (message.isCompleted) {
          sub.cancel();
          receivePort.close();
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  // --- Media Processing (FFmpeg CLI on Desktop / Mobile Bridge) ---

  Future<void> _executeMediaConversion(ConversionTask task, void Function(double progress)? onProgress) async {
    onProgress?.call(0.1);

    // Locate FFmpeg binary on host system
    final ffmpegPath = await _resolveFfmpegPath();
    if (ffmpegPath == null) {
      throw Exception(
        'FFmpeg executable not detected on system PATH. Install FFmpeg or enable PRO auto-bundle.',
      );
    }

    final List<String> arguments = [
      '-y', // Overwrite output without asking
      '-i', task.inputPath,
    ];

    // Check resolution caps according to licensing
    if (!licenseService.isPro) {
      // Free tier caps at 1080p
      arguments.addAll(['-vf', 'scale=-2:min(1080\\,ih)']);
    } else {
      // PRO Tier unlocks 4K and HW Accel
      final hwAccel = task.options['hwAccel'] as bool? ?? true;
      if (!kIsWeb && hwAccel && Platform.isWindows) {
        // Probe NVENC / QSV
        arguments.insertAll(1, ['-hwaccel', 'auto']);
      }
    }

    // Codec options
    final codec = task.options['codec'] as String? ?? 'auto';
    if (codec.contains('AV1')) {
      if (!licenseService.isPro) throw Exception('AV1 codec requires RetroFlux PRO.');
      arguments.addAll(['-c:v', 'libsvtav1', '-crf', '28']);
    } else if (codec.contains('HEVC') || codec.contains('H.265')) {
      if (!licenseService.isPro) throw Exception('HEVC encoding requires RetroFlux PRO.');
      arguments.addAll(['-c:v', 'libx265', '-crf', '24']);
    } else {
      arguments.addAll(['-c:v', 'libx264', '-preset', 'fast', '-crf', '22']);
    }

    arguments.addAll(['-c:a', 'aac', '-b:a', '192k', task.outputPath]);

    onProgress?.call(0.3);

    final process = await Process.start(ffmpegPath, arguments);

    // Listen to stderr for progress telemetry
    process.stderr.transform(utf8.decoder).listen((output) {
      if (output.contains('time=')) {
        // Dynamic time progress parse
        onProgress?.call(0.65);
      }
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('FFmpeg conversion failed with exit code $exitCode');
    }

    onProgress?.call(1.0);
  }

  // --- Data & Document Format Conversion (JSON, YAML, CSV, Markdown, TXT) ---

  Future<void> _executeDataConversion(ConversionTask task, void Function(double progress)? onProgress) async {
    onProgress?.call(0.2);
    final inputFile = File(task.inputPath);
    final rawText = await inputFile.readAsString();

    onProgress?.call(0.5);
    final fromExt = task.inputPath.split('.').last.toLowerCase();
    final toExt = task.targetFormat.toLowerCase();

    dynamic parsedData;
    if (fromExt == 'json') {
      parsedData = jsonDecode(rawText);
    } else if (fromExt == 'csv') {
      parsedData = _parseCsv(rawText);
    } else {
      parsedData = {'raw': rawText};
    }

    onProgress?.call(0.8);
    String convertedOutput = '';
    if (toExt == 'json') {
      convertedOutput = const JsonEncoder.withIndent('  ').convert(parsedData);
    } else if (toExt == 'csv') {
      convertedOutput = _convertToCsv(parsedData);
    } else {
      convertedOutput = rawText;
    }

    final outputFile = File(task.outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(convertedOutput);

    onProgress?.call(1.0);
  }

  Future<void> _executeDocumentConversion(ConversionTask task, void Function(double progress)? onProgress) async {
    await OfficeEngine.convert(
      inputPath: task.inputPath,
      outputPath: task.outputPath,
      targetFormat: task.targetFormat,
      onProgress: onProgress,
    );
  }

  // --- Utility Resolvers ---

  static Future<String?> _resolveFfmpegPath() async {
    if (kIsWeb) return null;

    // 1. Check WinGet Links
    if (Platform.isWindows) {
      const winGetPath = r'C:\Users\bonno\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe';
      if (File(winGetPath).existsSync()) return winGetPath;
    }

    // 2. Query system PATH
    try {
      final cmd = Platform.isWindows ? 'where.exe' : 'which';
      final res = await Process.run(cmd, ['ffmpeg']);
      if (res.exitCode == 0) {
        final path = res.stdout.toString().split('\n').first.trim();
        if (File(path).existsSync()) return path;
      }
    } catch (_) {}

    return null;
  }

  static List<Map<String, dynamic>> _parseCsv(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final List<Map<String, dynamic>> results = [];

    for (var i = 1; i < lines.length; i++) {
      final values = lines[i].split(',').map((v) => v.trim()).toList();
      final map = <String, dynamic>{};
      for (var j = 0; j < headers.length && j < values.length; j++) {
        map[headers[j]] = values[j];
      }
      results.add(map);
    }
    return results;
  }

  static String _convertToCsv(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map) {
      final headers = (data.first as Map).keys.join(',');
      final rows = data.map((item) => (item as Map).values.join(',')).join('\n');
      return '$headers\n$rows';
    }
    return data.toString();
  }
}
