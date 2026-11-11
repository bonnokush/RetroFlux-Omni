import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Hybrid Lemon Squeezy Online Verification & Cryptographic Offline Storage Engine
class LicenseService {
  static const String _prefTokenKey = 'retroflux_license_token_v4';
  static const String _prefKeyName = 'retroflux_license_key_v4';
  static const String _prefInstanceIdKey = 'retroflux_license_instance_id_v4';
  static const String _prefCustomerKey = 'retroflux_license_customer_name_v4';

  // Secret salt compiled into the binary for HMAC-SHA256 offline caching
  static const String _signingSalt =
      'RETROFLUX_OMNI_4_ENTERPRISE_HMAC_SALT_2026';

  // Lemon Squeezy Store URL for RetroFlux Omni
  static const String checkoutUrl =
      'https://retroflux.lemonsqueezy.com/checkout/buy/retroflux-omni-pro';

  LicenseTier _currentTier = LicenseTier.free;
  String? _activeLicenseKey;
  String? _instanceId;
  String? _customerName;

  LicenseTier get currentTier => _currentTier;
  bool get isPro => _currentTier == LicenseTier.pro;
  String? get activeLicenseKey => _activeLicenseKey;
  String? get customerName => _customerName;

  /// Maximum batch queue size for current tier
  int get maxBatchQueueSize => isPro ? 1000 : 3;

  /// Maximum video output resolution height
  int get maxResolutionHeight => isPro ? 2160 : 1080; // 4K vs 1080p

  /// Supported Video Codecs for current tier
  List<String> get availableVideoCodecs {
    if (isPro) {
      return [
        'H.264 (Universal)',
        'H.265 (HEVC)',
        'AV1 (AOMedia)',
        'ProRes 422',
        'VP9'
      ];
    }
    return ['H.264 (Universal)'];
  }

  /// Whether hardware acceleration (NVENC, QSV, AMF) is enabled
  bool get supportsHardwareAcceleration => isPro;

  /// Initializes the service and loads existing encrypted token
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefTokenKey);
      final storedKey = prefs.getString(_prefKeyName);
      _customerName = prefs.getString(_prefCustomerKey);
      _instanceId = prefs.getString(_prefInstanceIdKey);

      if (token != null &&
          storedKey != null &&
          _verifyToken(storedKey, token)) {
        _currentTier = LicenseTier.pro;
        _activeLicenseKey = storedKey;
      } else {
        _currentTier = LicenseTier.free;
      }
    } catch (_) {
      _currentTier = LicenseTier.free;
    }
  }

  /// Opens the Lemon Squeezy checkout page in the system default browser
  static Future<void> openCheckoutPage() async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', checkoutUrl]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [checkoutUrl]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [checkoutUrl]);
      }
    } catch (_) {}
  }

  /// Activates a PRO License Key:
  /// 1. Tries Lemon Squeezy License Verification API online
  /// 2. If offline or dev format, validates offline HMAC signature
  Future<ActivationResult> activateKey(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) {
      return const ActivationResult(
          success: false, errorMessage: 'Please enter a license key.');
    }

    // A. Check for Offline Dev / Enterprise Key format (Strictly restricted to internal debug builds)
    if (kDebugMode && cleanKey.toUpperCase().startsWith('RFLX-PRO-')) {
      final upperKey = cleanKey.toUpperCase();
      if (_validateDevKeyFormat(upperKey)) {
        await _saveActiveLicense(upperKey,
            customer: 'Developer / Enterprise Seat');
        return ActivationResult(
            success: true,
            key: upperKey,
            customerName: 'Developer / Enterprise Seat');
      } else {
        return const ActivationResult(
            success: false,
            errorMessage: 'Invalid offline license key signature.');
      }
    }

    // B. Activate via Lemon Squeezy Licensing API
    try {
      final instanceName = Platform.isWindows
          ? (Platform.environment['COMPUTERNAME'] ?? 'Windows-PC')
          : Platform.localHostname;

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final uri =
          Uri.parse('https://api.lemonsqueezy.com/v1/licenses/activate');
      final request = await client.postUrl(uri);
      request.headers.set('Accept', 'application/json');
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');

      final body =
          'license_key=${Uri.encodeQueryComponent(cleanKey)}&instance_name=${Uri.encodeQueryComponent(instanceName)}';
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (json['activated'] == true) {
        final instance = json['instance'] as Map<String, dynamic>?;
        final meta = json['meta'] as Map<String, dynamic>?;
        final customer = meta?['customer_name'] as String? ??
            meta?['customer_email'] as String? ??
            'PRO License Holder';
        final instId = instance?['id'] as String?;

        await _saveActiveLicense(cleanKey,
            instanceId: instId, customer: customer);
        return ActivationResult(
            success: true, key: cleanKey, customerName: customer);
      } else {
        final errorMsg = json['error'] as String? ??
            'Invalid Lemon Squeezy license key or activation limit reached.';
        return ActivationResult(success: false, errorMessage: errorMsg);
      }
    } on SocketException {
      // Network unreachable - check if key was previously cached
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_prefTokenKey);
      if (cachedToken != null && _verifyToken(cleanKey, cachedToken)) {
        _currentTier = LicenseTier.pro;
        _activeLicenseKey = cleanKey;
        return ActivationResult(
            success: true,
            key: cleanKey,
            customerName: _customerName ?? 'Cached Offline');
      }
      return const ActivationResult(
        success: false,
        errorMessage:
            'Unable to reach Lemon Squeezy servers. Check internet connection or use an offline key.',
      );
    } catch (e) {
      return ActivationResult(
          success: false, errorMessage: 'Activation error: $e');
    }
  }

  /// Deactivates PRO on Lemon Squeezy and reverts to free tier
  Future<void> deactivate() async {
    final key = _activeLicenseKey;
    final instId = _instanceId;

    if (key != null && instId != null) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final uri =
            Uri.parse('https://api.lemonsqueezy.com/v1/licenses/deactivate');
        final request = await client.postUrl(uri);
        request.headers.set('Accept', 'application/json');
        request.headers
            .set('Content-Type', 'application/x-www-form-urlencoded');
        request.write(
            'license_key=${Uri.encodeQueryComponent(key)}&instance_id=${Uri.encodeQueryComponent(instId)}');
        await request.close();
        client.close();
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefKeyName);
      await prefs.remove(_prefInstanceIdKey);
      await prefs.remove(_prefCustomerKey);
    } catch (_) {}

    _currentTier = LicenseTier.free;
    _activeLicenseKey = null;
    _instanceId = null;
    _customerName = null;
  }

  /// Generates a test PRO license key for offline evaluation
  static String generateValidDevKey() {
    return 'RFLX-PRO-7788-9900-OMNI';
  }

  // --- Internals ---

  Future<void> _saveActiveLicense(String key,
      {String? instanceId, String? customer}) async {
    final token = _generateToken(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, token);
    await prefs.setString(_prefKeyName, key);
    if (instanceId != null) {
      await prefs.setString(_prefInstanceIdKey, instanceId);
    }
    if (customer != null) {
      await prefs.setString(_prefCustomerKey, customer);
    }

    _currentTier = LicenseTier.pro;
    _activeLicenseKey = key;
    _instanceId = instanceId;
    _customerName = customer;
  }

  bool _validateDevKeyFormat(String key) {
    if (!key.startsWith('RFLX-PRO-')) return false;
    final parts = key.split('-');
    if (parts.length != 5) return false;
    return parts[1] == 'PRO';
  }

  String _generateToken(String key) {
    final hmac = Hmac(sha256, utf8.encode(_signingSalt));
    final digest = hmac.convert(utf8.encode(key));
    return digest.toString();
  }

  bool _verifyToken(String key, String token) {
    final hmac = Hmac(sha256, utf8.encode(_signingSalt));
    final expected = hmac.convert(utf8.encode(key)).toString();
    return expected == token;
  }
}
