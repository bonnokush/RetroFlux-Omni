import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/license_service.dart';

/// Riverpod Providers for Architecture State
final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService();
});

final licenseStateProvider =
    StateNotifierProvider<LicenseStateNotifier, LicenseTier>((ref) {
  final service = ref.watch(licenseServiceProvider);
  return LicenseStateNotifier(service);
});

class LicenseStateNotifier extends StateNotifier<LicenseTier> {
  final LicenseService _service;

  LicenseStateNotifier(this._service) : super(_service.currentTier) {
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
    state = _service.currentTier;
  }

  Future<ActivationResult> activateKey(String key) async {
    final result = await _service.activateKey(key);
    state = _service.currentTier;
    return result;
  }

  Future<void> deactivate() async {
    await _service.deactivate();
    state = _service.currentTier;
  }
}

/// RetroFlux Omni PRO Status Dialog (Option 1: Microsoft Store Edition)
class ProModal extends ConsumerWidget {
  const ProModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ProModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surfaceContainer,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Icon
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RETROFLUX PRO 4.0',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: colorScheme.onSurface),
                      ),
                      Text(
                        'Microsoft Store Edition • Lifetime License Active',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Active License Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Lifetime Access Unlocked',
                          style: TextStyle(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        Text(
                          'Verified via Microsoft Store • Zero Telemetry',
                          style: TextStyle(
                              color: colorScheme.onSecondaryContainer
                                  .withOpacity(0.8),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Feature List
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _FeatureRow(
                      icon: Icons.hd,
                      text: '4K Ultra HD Export (Up to 2160p 60FPS)',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.bolt,
                      text:
                          'Direct Silicon GPU Accel (Intel QSV, NVENC, AMD AMF)',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.flash_on,
                      text: 'Instant Lossless Remuxing (-c copy stream copy)',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.all_inclusive,
                      text: 'Unlimited Batch Queue with Parallel Workers',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.video_file,
                      text: 'Next-Gen Codecs: AV1, HEVC, ProRes 422, VP9',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.image,
                      text: 'Multi-Threaded Isolate Pools for Image Studio',
                      colorScheme: colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Button
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'DONE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;

  const _FeatureRow(
      {required this.icon, required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
