import 'dart:async';

/// License Tier Definition
enum LicenseTier {
  free,
  pro,
}

/// Result of an activation attempt
class ActivationResult {
  final bool success;
  final String? errorMessage;
  final String? customerName;
  final String? key;

  const ActivationResult({
    required this.success,
    this.errorMessage,
    this.customerName,
    this.key,
  });
}

/// Microsoft Store One-Time Purchase Licensing Engine
/// All features are 100% unlocked for the Store Edition (Option 1)
class LicenseService {
  LicenseTier _currentTier = LicenseTier.pro;
  String? _activeLicenseKey = 'MICROSOFT-STORE-LIFETIME-PRO';
  String? _customerName = 'Microsoft Store Edition';

  LicenseTier get currentTier => _currentTier;
  bool get isPro => true;
  String? get activeLicenseKey => _activeLicenseKey;
  String? get customerName => _customerName;

  /// Maximum batch queue size for current tier
  int get maxBatchQueueSize => 1000; // Unlimited

  /// Maximum video output resolution height
  int get maxResolutionHeight => 2160; // Full 4K UHD

  /// Supported Video Codecs for current tier
  List<String> get availableVideoCodecs => const [
        'H.264 (Universal)',
        'H.265 (HEVC)',
        'AV1 (AOMedia)',
        'ProRes 422',
        'VP9'
      ];

  /// Whether hardware acceleration (NVENC, QSV, AMF) is enabled
  bool get supportsHardwareAcceleration => true;

  /// Initializes the service - Option 1 Store Edition is permanently unlocked
  Future<void> initialize() async {
    _currentTier = LicenseTier.pro;
    _activeLicenseKey = 'MICROSOFT-STORE-LIFETIME-PRO';
    _customerName = 'Microsoft Store Edition';
  }

  Future<ActivationResult> activateKey(String key) async {
    return const ActivationResult(
      success: true,
      key: 'MICROSOFT-STORE-LIFETIME-PRO',
      customerName: 'Microsoft Store Edition',
    );
  }

  Future<void> deactivate() async {
    // In Store Edition, access is permanent
  }

  static String generateValidDevKey() => 'RFLX-PRO-STORE-VERIFIED';
}
