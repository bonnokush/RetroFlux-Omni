import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retroflux_omni/core/license_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RetroFlux Option 1 Microsoft Store Licensing Tests', () {
    test('LicenseService defaults to PRO tier with full access', () async {
      final service = LicenseService();
      await service.initialize();
      expect(service.isPro, isTrue);
      expect(service.currentTier, equals(LicenseTier.pro));
      expect(service.maxBatchQueueSize, equals(1000)); // Unlimited
      expect(service.maxResolutionHeight, equals(2160)); // 4K UHD
      expect(service.supportsHardwareAcceleration, isTrue);
      expect(service.availableVideoCodecs.contains('AV1 (AOMedia)'), isTrue);
      expect(service.availableVideoCodecs.contains('H.265 (HEVC)'), isTrue);
    });

    test('Store Edition customer name and key are active', () async {
      final service = LicenseService();
      await service.initialize();
      expect(service.customerName, equals('Microsoft Store Edition'));
      expect(service.activeLicenseKey, equals('MICROSOFT-STORE-LIFETIME-PRO'));
    });
  });
}
