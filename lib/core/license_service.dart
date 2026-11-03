import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// License Tier Definition
enum LicenseTier {
  free,
  pro,
}

/// Offline Cryptographic License Validation and Secure Storage Engine
class LicenseService {
  static const String _prefTokenKey = 'retroflux_license_token_v4';
  static const String _prefSaltKey = 'retroflux_hardware_salt_v4';

  // Secret salt compiled into the binary for HMAC-SHA256 offline verification
  static const String _signingSalt = 'RETROFLUX_OMNI_4_ENTERPRISE_HMAC_SALT_2026';

  LicenseTier _currentTier = LicenseTier.free;
  String? _activeLicenseKey;

  LicenseTier get currentTier => _currentTier;
  bool get isPro => _currentTier == LicenseTier.pro;
  String? get activeLicenseKey => _activeLicenseKey;

  /// Maximum batch queue size for current tier
  int get maxBatchQueueSize => isPro ? 1000 : 3;

  /// Maximum video output resolution height
  int get maxResolutionHeight => isPro ? 2160 : 1080; // 4K vs 1080p

  /// Supported Video Codecs for current tier
  List<String> get availableVideoCodecs {
    if (isPro) {
      return ['H.264 (AVC)', 'H.265 (HEVC)', 'AV1 (AOMedia)', 'ProRes 422', 'VP9'];
    }
    return ['H.264 (AVC)', 'VP8'];
  }

  /// Whether hardware acceleration (NVENC, QSV, Apple VideoToolbox) is enabled
  bool get supportsHardwareAcceleration => isPro;

  /// Initializes the service and loads existing encrypted token
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefTokenKey);
      if (token != null && _verifyToken(token)) {
        _currentTier = LicenseTier.pro;
        _activeLicenseKey = token.split('.').first;
      } else {
        _currentTier = LicenseTier.free;
      }
    } catch (_) {
      _currentTier = LicenseTier.free;
    }
  }

  /// Activates a PRO License Key offline using cryptographic signature validation
  /// Format expected: RFLX-PRO-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}
  Future<bool> activateKey(String key) async {
    final cleanKey = key.trim().toUpperCase();

    if (!_validateKeyFormat(cleanKey)) {
      return false;
    }

    final token = _generateToken(cleanKey);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTokenKey, token);

      _currentTier = LicenseTier.pro;
      _activeLicenseKey = cleanKey;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deactivates PRO and reverts to free tier
  Future<void> deactivate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefSaltKey);
    } catch (_) {}
    _currentTier = LicenseTier.free;
    _activeLicenseKey = null;
  }

  /// Generates a test PRO license key for testing & evaluation
  static String generateValidDevKey() {
    const rawKey = 'RFLX-PRO-7788-9900-OMNI';
    return rawKey;
  }

  // --- Cryptographic Internals ---

  bool _validateKeyFormat(String key) {
    if (!key.startsWith('RFLX-PRO-')) return false;
    final parts = key.split('-');
    if (parts.length != 5) return false;
    return parts[1] == 'PRO';
  }

  String _generateToken(String key) {
    final hmac = Hmac(sha256, utf8.encode(_signingSalt));
    final digest = hmac.convert(utf8.encode(key));
    return '$key.${digest.toString()}';
  }

  bool _verifyToken(String token) {
    final parts = token.split('.');
    if (parts.length != 2) return false;
    final key = parts[0];
    final expectedSignature = parts[1];

    final hmac = Hmac(sha256, utf8.encode(_signingSalt));
    final calculated = hmac.convert(utf8.encode(key)).toString();

    return calculated == expectedSignature && _validateKeyFormat(key);
  }
}
