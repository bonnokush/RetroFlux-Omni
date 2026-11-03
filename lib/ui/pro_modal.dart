import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/license_service.dart';

/// Riverpod Providers for Architecture State
final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService();
});

final licenseStateProvider = StateNotifierProvider<LicenseStateNotifier, LicenseTier>((ref) {
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

  Future<bool> activateKey(String key) async {
    final success = await _service.activateKey(key);
    if (success) {
      state = _service.currentTier;
    }
    return success;
  }

  Future<void> deactivate() async {
    await _service.deactivate();
    state = _service.currentTier;
  }
}

/// PRO License Key Activation Modal Dialog
/// Material 3 Dialog (BorderRadius.circular(28) & Zero Outline)
class ProModal extends ConsumerStatefulWidget {
  const ProModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ProModal(),
    );
  }

  @override
  ConsumerState<ProModal> createState() => _ProModalState();
}

class _ProModalState extends ConsumerState<ProModal> {
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter a license key');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await ref.read(licenseStateProvider.notifier).activateKey(key);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('RetroFlux PRO activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _error = 'Invalid license key signature');
      }
    }
  }

  void _fillDevKey() {
    _keyController.text = LicenseService.generateValidDevKey();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(licenseStateProvider) == LicenseTier.pro;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surfaceContainer,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with PRO badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.workspace_premium, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RETROFLUX PRO 4.0',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: colorScheme.onSurface),
                      ),
                      Text(
                        'Offline High-Throughput Engine',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
            const SizedBox(height: 20),

            // Feature Comparison
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _FeatureRow(icon: Icons.all_inclusive, text: 'Unlimited Batch Queue (vs. 3 on Free)', colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(icon: Icons.hd, text: '4K Ultra HD Export (vs. 1080p Cap)', colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(icon: Icons.memory, text: 'Hardware GPU Acceleration (NVENC/QSV/VideoToolbox)', colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(icon: Icons.video_file, text: 'Next-Gen Codecs: AV1, HEVC, ProRes 422', colorScheme: colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isPro) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'License Active (Perpetual Offline)',
                        style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: () async {
                        await ref.read(licenseStateProvider.notifier).deactivate();
                        if (mounted) setState(() {});
                      },
                      child: Text('Deactivate', style: TextStyle(color: colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _keyController,
                style: TextStyle(fontFamily: 'Consolas', fontSize: 14, letterSpacing: 1, color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'ENTER PRO LICENSE KEY',
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                  hintText: 'RFLX-PRO-XXXX-XXXX-XXXX',
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(shape: const StadiumBorder()),
                    icon: Icon(Icons.auto_fix_high, size: 14, color: colorScheme.primary),
                    label: Text('Fill Dev License', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _fillDevKey,
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _activate,
                    child: _isLoading
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary))
                        : const Text('ACTIVATE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ],
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

  const _FeatureRow({required this.icon, required this.text, required this.colorScheme});

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
