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
    if (result.success) {
      state = _service.currentTier;
    }
    return result;
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
      setState(() => _error = 'Please enter your license key');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result =
        await ref.read(licenseStateProvider.notifier).activateKey(key);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚡ RetroFlux PRO activated! ${result.customerName != null ? "Licensed to ${result.customerName}" : ""}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _error = result.errorMessage ?? 'Invalid license key');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(licenseStateProvider) == LicenseTier.pro;
    final licenseService = ref.watch(licenseServiceProvider);
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
            // Header with PRO badge
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
                        'Hardware-Accelerated 4K Engine',
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

            // Feature Comparison
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
                      text: '4K Ultra HD Export (vs. 1080p Cap on Free)',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.bolt,
                      text:
                          'Intel QSV / NVIDIA NVENC / AMD AMF GPU Acceleration',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.flash_on,
                      text: 'Instant Lossless Remuxing (-c copy)',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.all_inclusive,
                      text: 'Unlimited Batch Queue (vs. 3 items on Free)',
                      colorScheme: colorScheme),
                  const SizedBox(height: 10),
                  _FeatureRow(
                      icon: Icons.video_file,
                      text: 'Next-Gen Codecs: AV1, HEVC, ProRes 422',
                      colorScheme: colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isPro) ...[
              // Active License Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: colorScheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRO Lifetime License Active',
                            style: TextStyle(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          if (licenseService.customerName != null)
                            Text(
                              licenseService.customerName!,
                              style: TextStyle(
                                  color: colorScheme.onSecondaryContainer
                                      .withOpacity(0.8),
                                  fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: () async {
                        await ref
                            .read(licenseStateProvider.notifier)
                            .deactivate();
                        if (mounted) setState(() {});
                      },
                      child: Text('Deactivate',
                          style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Primary Lemon Squeezy Buy Button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text(
                  'BUY RETROFLUX PRO ON LEMON SQUEEZY',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5),
                ),
                onPressed: LicenseService.openCheckoutPage,
              ),
              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR ACTIVATE WITH LICENSE KEY',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                ],
              ),
              const SizedBox(height: 16),

              // License Key Input
              TextField(
                controller: _keyController,
                style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'ENTER LICENSE KEY',
                  labelStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 11),
                  hintText: 'Paste Lemon Squeezy or Offline Key',
                  hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      fontSize: 12),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _activate,
                    child: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colorScheme.primary))
                        : const Text('ACTIVATE LICENSE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
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
