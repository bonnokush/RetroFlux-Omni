import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'worker_isolate.dart';
import 'license_service.dart';

/// Detected hardware acceleration capabilities on host system
class GpuCapabilities {
  final bool hasIntelQsv;
  final bool hasNvidiaNvenc;
  final bool hasAmdAmf;
  final bool hasAppleVideoToolbox;

  const GpuCapabilities({
    this.hasIntelQsv = false,
    this.hasNvidiaNvenc = false,
    this.hasAmdAmf = false,
    this.hasAppleVideoToolbox = false,
  });

  bool get hasAnyGpu =>
      hasIntelQsv || hasNvidiaNvenc || hasAmdAmf || hasAppleVideoToolbox;

  String get preferredVendorLabel {
    if (hasNvidiaNvenc) return 'NVIDIA NVENC';
    if (hasIntelQsv) return 'Intel QuickSync (QSV)';
    if (hasAmdAmf) return 'AMD AMF';
    if (hasAppleVideoToolbox) return 'Apple VideoToolbox';
    return 'Multi-Threaded CPU';
  }
}

/// Dedicated High-Performance Media & Image Engine Bridge
class EngineBridge {
  final LicenseService licenseService;
  final WorkerIsolatePool workerPool;

  static GpuCapabilities? _cachedGpu;
  static String? _cachedFfmpegPath;

  EngineBridge({
    required this.licenseService,
    WorkerIsolatePool? workerPool,
  }) : workerPool = workerPool ?? WorkerIsolatePool();

  /// Converts a single task using the optimal platform engine
  Future<void> executeTask(ConversionTask task,
      {void Function(double progress)? onProgress}) async {
    switch (task.category) {
      case TaskCategory.media:
        await _executeMediaConversion(task, onProgress);
        break;
      case TaskCategory.image:
        await _executeImageConversion(task, onProgress);
        break;
      case TaskCategory.document:
      case TaskCategory.data:
        // Graceful fallback for non-media tasks: media extraction or text passthrough
        await _executePassthroughFallback(task, onProgress);
        break;
    }
  }

  // --- Image Processing (Zero UI Blocking Dart Isolate Worker) ---

  Future<void> _executeImageConversion(
      ConversionTask task, void Function(double progress)? onProgress) async {
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

  // --- High-Performance 4K Video & Audio Engine (FFmpeg HW Accel) ---

  Future<void> _executeMediaConversion(
      ConversionTask task, void Function(double progress)? onProgress) async {
    onProgress?.call(0.02);

    final ffmpegPath = await resolveFfmpegPath();
    if (ffmpegPath == null) {
      throw Exception(
        'FFmpeg executable not detected on system PATH. Install FFmpeg or enable auto-detection.',
      );
    }

    final gpu = await detectGpuCapabilities(ffmpegPath);
    final targetExt = task.targetFormat.toLowerCase().replaceAll('.', '');
    final isAudioTarget = [
      'mp3',
      'wav',
      'aac',
      'flac',
      'm4a',
      'ogg',
      'opus',
      'wma'
    ].contains(targetExt);
    final isLosslessRemux = task.options['losslessRemux'] as bool? ?? false;

    final List<String> arguments = [
      '-y', // Overwrite destination without confirmation
      '-hide_banner',
    ];

    // Hardware decoder acceleration before input (Unlocked for all tiers)
    final hwAccelEnabled = task.options['hwAccel'] as bool? ?? true;
    if (hwAccelEnabled && !isLosslessRemux && !isAudioTarget) {
      if (gpu.hasIntelQsv) {
        arguments.addAll(['-hwaccel', 'qsv']);
      } else if (gpu.hasNvidiaNvenc) {
        arguments.addAll(['-hwaccel', 'cuda']);
      } else if (Platform.isWindows) {
        arguments.addAll(['-hwaccel', 'd3d11va']);
      }
    }

    // Input file
    arguments.addAll(['-i', task.inputPath]);

    // Build encoding or remuxing arguments
    if (isLosslessRemux) {
      // ⚡ Instant Lossless Stream Copy (1-2 seconds for 20GB+ 4K files)
      arguments.addAll([
        '-c:v',
        'copy',
        '-c:a',
        'copy',
        '-map',
        '0',
      ]);
      task.statusDetail = 'Lossless Stream Copy (Zero quality loss)';
    } else if (isAudioTarget) {
      // High-Fidelity Audio Extraction / Transcoding
      arguments.add('-vn'); // Strip video track
      switch (targetExt) {
        case 'mp3':
          arguments.addAll(['-c:a', 'libmp3lame', '-b:a', '320k']);
          break;
        case 'wav':
          arguments.addAll(['-c:a', 'pcm_s16le']);
          break;
        case 'flac':
          arguments.addAll(['-c:a', 'flac']);
          break;
        case 'aac':
        case 'm4a':
          arguments.addAll(['-c:a', 'aac', '-b:a', '256k']);
          break;
        case 'ogg':
        case 'opus':
          arguments.addAll(['-c:a', 'libopus', '-b:a', '192k']);
          break;
        default:
          arguments.addAll(['-c:a', 'aac', '-b:a', '192k']);
          break;
      }
      task.statusDetail = 'Extracting Hi-Fi Audio (${targetExt.toUpperCase()})';
    } else {
      // ⚡ 4K / HD Video Transcoding with GPU Acceleration
      final requestedCodec =
          task.options['codec'] as String? ?? 'H.264 (Universal)';
      final requestedRes =
          task.options['resolution'] as String? ?? 'Original Source';

      // 1. Resolution & Scale Filters
      if (!licenseService.isPro) {
        // Free tier capped at 1080p
        arguments.addAll(['-vf', 'scale=-2:min(1080\\,ih)']);
      } else {
        if (requestedRes.contains('4K')) {
          arguments.addAll(['-vf', 'scale=-2:2160']);
        } else if (requestedRes.contains('1440p') ||
            requestedRes.contains('2.5K')) {
          arguments.addAll(['-vf', 'scale=-2:1440']);
        } else if (requestedRes.contains('1080p')) {
          arguments.addAll(['-vf', 'scale=-2:1080']);
        } else if (requestedRes.contains('720p')) {
          arguments.addAll(['-vf', 'scale=-2:720']);
        }
      }

      // 2. Video Codec Selection (Hardware vs Software)
      if (requestedCodec.contains('HEVC') || requestedCodec.contains('H.265')) {
        if (!licenseService.isPro) {
          throw Exception('HEVC / 4K encoding requires RetroFlux PRO.');
        }
        if (hwAccelEnabled && gpu.hasIntelQsv) {
          arguments.addAll([
            '-c:v',
            'hevc_qsv',
            '-global_quality',
            '23',
            '-preset',
            'medium'
          ]);
          task.statusDetail = 'Encoding HEVC via Intel QSV';
        } else if (hwAccelEnabled && gpu.hasNvidiaNvenc) {
          arguments
              .addAll(['-c:v', 'hevc_nvenc', '-preset', 'p4', '-cq', '24']);
          task.statusDetail = 'Encoding HEVC via NVIDIA NVENC';
        } else if (hwAccelEnabled && gpu.hasAmdAmf) {
          arguments.addAll(['-c:v', 'hevc_amf', '-quality', 'quality']);
          task.statusDetail = 'Encoding HEVC via AMD AMF';
        } else {
          arguments.addAll([
            '-c:v',
            'libx265',
            '-crf',
            '24',
            '-preset',
            'fast',
            '-threads',
            '0'
          ]);
          task.statusDetail = 'Encoding HEVC via Multi-Threaded CPU';
        }
      } else if (requestedCodec.contains('AV1')) {
        if (!licenseService.isPro) {
          throw Exception('AV1 encoding requires RetroFlux PRO.');
        }
        if (hwAccelEnabled && gpu.hasIntelQsv) {
          arguments.addAll(['-c:v', 'av1_qsv', '-global_quality', '25']);
          task.statusDetail = 'Encoding AV1 via Intel QSV';
        } else if (hwAccelEnabled && gpu.hasNvidiaNvenc) {
          arguments.addAll(['-c:v', 'av1_nvenc', '-preset', 'p4', '-cq', '26']);
          task.statusDetail = 'Encoding AV1 via NVIDIA NVENC';
        } else {
          arguments.addAll(['-c:v', 'libsvtav1', '-crf', '28', '-preset', '6']);
          task.statusDetail = 'Encoding AV1 via SVT-AV1 CPU';
        }
      } else {
        // Universal H.264
        if (hwAccelEnabled && gpu.hasIntelQsv) {
          arguments.addAll(['-c:v', 'h264_qsv', '-global_quality', '21']);
          task.statusDetail = 'Encoding H.264 via Intel QSV';
        } else if (hwAccelEnabled && gpu.hasNvidiaNvenc) {
          arguments
              .addAll(['-c:v', 'h264_nvenc', '-preset', 'p4', '-cq', '22']);
          task.statusDetail = 'Encoding H.264 via NVIDIA NVENC';
        } else if (hwAccelEnabled && gpu.hasAmdAmf) {
          arguments.addAll(['-c:v', 'h264_amf', '-quality', 'quality']);
          task.statusDetail = 'Encoding H.264 via AMD AMF';
        } else {
          arguments.addAll([
            '-c:v',
            'libx264',
            '-crf',
            '22',
            '-preset',
            'fast',
            '-threads',
            '0'
          ]);
          task.statusDetail = 'Encoding H.264 via Multi-Threaded CPU';
        }
      }

      // Audio track
      arguments.addAll(['-c:a', 'aac', '-b:a', '192k']);
    }

    // Ensure output directory exists and append output file path
    final outputFile = File(task.outputPath);
    await outputFile.parent.create(recursive: true);
    arguments.add(task.outputPath);

    // Launch FFmpeg Process
    final process = await Process.start(ffmpegPath, arguments);

    // Telemetry & Dynamic Progress Tracking
    double totalDurationSeconds = 0.0;
    final durationRegex = RegExp(r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)');
    final timeRegex = RegExp(r'time=\s*(\d+):(\d+):(\d+(?:\.\d+)?)');
    final speedRegex = RegExp(r'speed=\s*([\d\.]+)x');
    final fpsRegex = RegExp(r'fps=\s*([\d\.]+)');

    process.stderr.transform(utf8.decoder).listen((output) {
      // 1. Probe total duration from stream headers
      if (totalDurationSeconds == 0.0) {
        final match = durationRegex.firstMatch(output);
        if (match != null) {
          final h = double.tryParse(match.group(1)!) ?? 0;
          final m = double.tryParse(match.group(2)!) ?? 0;
          final s = double.tryParse(match.group(3)!) ?? 0;
          totalDurationSeconds = (h * 3600) + (m * 60) + s;
        }
      }

      // 2. Parse current elapsed encode time
      final timeMatch = timeRegex.firstMatch(output);
      if (timeMatch != null && totalDurationSeconds > 0) {
        final h = double.tryParse(timeMatch.group(1)!) ?? 0;
        final m = double.tryParse(timeMatch.group(2)!) ?? 0;
        final s = double.tryParse(timeMatch.group(3)!) ?? 0;
        final currentSeconds = (h * 3600) + (m * 60) + s;

        final rawProgress =
            (currentSeconds / totalDurationSeconds).clamp(0.0, 0.99);
        task.progress = rawProgress;
        onProgress?.call(rawProgress);
      }

      // 3. Parse speed and fps metrics
      final speedMatch = speedRegex.firstMatch(output);
      if (speedMatch != null) {
        task.speed = '${speedMatch.group(1)}x';
      }

      final fpsMatch = fpsRegex.firstMatch(output);
      if (fpsMatch != null) {
        task.fps = double.tryParse(fpsMatch.group(1)!);
      }
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('FFmpeg process failed with exit code $exitCode');
    }

    task.progress = 1.0;
    task.statusDetail =
        isLosslessRemux ? 'Lossless Remux Complete' : 'Encoding Complete';
    onProgress?.call(1.0);
  }

  // --- Fallback Passthrough ---
  Future<void> _executePassthroughFallback(
      ConversionTask task, void Function(double progress)? onProgress) async {
    onProgress?.call(0.5);
    final src = File(task.inputPath);
    final dst = File(task.outputPath);
    await dst.parent.create(recursive: true);
    await src.copy(dst.path);
    onProgress?.call(1.0);
  }

  // --- Hardware Capabilities & FFmpeg Resolvers ---

  static Future<String?> resolveFfmpegPath() async {
    if (kIsWeb) return null;
    if (_cachedFfmpegPath != null && File(_cachedFfmpegPath!).existsSync()) {
      return _cachedFfmpegPath;
    }

    // 1. Check local application directory (companion portable FFmpeg)
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final portablePath = Platform.isWindows
        ? '$appDir\\ffmpeg.exe'
        : '$appDir/ffmpeg';
    if (File(portablePath).existsSync()) {
      _cachedFfmpegPath = portablePath;
      return portablePath;
    }

    // 2. Check dynamic WinGet Links on Windows
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        final winGetPath = '$localAppData\\Microsoft\\WinGet\\Links\\ffmpeg.exe';
        if (File(winGetPath).existsSync()) {
          _cachedFfmpegPath = winGetPath;
          return winGetPath;
        }
      }
    }

    // 3. Query system PATH
    try {
      final cmd = Platform.isWindows ? 'where.exe' : 'which';
      final res = await Process.run(cmd, ['ffmpeg']);
      if (res.exitCode == 0) {
        final path = res.stdout.toString().split(RegExp(r'[\r\n]+')).first.trim();
        if (path.isNotEmpty && File(path).existsSync()) {
          _cachedFfmpegPath = path;
          return path;
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<GpuCapabilities> detectGpuCapabilities(
      [String? ffmpegPath]) async {
    if (_cachedGpu != null) return _cachedGpu!;

    final path = ffmpegPath ?? await resolveFfmpegPath();
    if (path == null) {
      return const GpuCapabilities();
    }

    try {
      final res = await Process.run(path, ['-encoders']);
      final stdout = res.stdout.toString().toLowerCase();

      final hasIntelQsv =
          stdout.contains('hevc_qsv') || stdout.contains('h264_qsv');
      final hasNvidiaNvenc =
          stdout.contains('hevc_nvenc') || stdout.contains('h264_nvenc');
      final hasAmdAmf =
          stdout.contains('hevc_amf') || stdout.contains('h264_amf');
      final hasAppleVideoToolbox = stdout.contains('videotoolbox');

      _cachedGpu = GpuCapabilities(
        hasIntelQsv: hasIntelQsv,
        hasNvidiaNvenc: hasNvidiaNvenc,
        hasAmdAmf: hasAmdAmf,
        hasAppleVideoToolbox: hasAppleVideoToolbox,
      );
      return _cachedGpu!;
    } catch (_) {
      return const GpuCapabilities();
    }
  }
}
