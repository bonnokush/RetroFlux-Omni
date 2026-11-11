import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retroflux_omni/core/license_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RetroFlux License Cryptographic Verification Tests', () {
    test('Dev Key format passes format validation', () {
      final devKey = LicenseService.generateValidDevKey();
      expect(devKey.startsWith('RFLX-PRO-'), isTrue);
      expect(devKey.split('-').length, equals(5));
    });

    test('LicenseService defaults to Free tier before activation', () {
      final service = LicenseService();
      expect(service.isPro, isFalse);
      expect(service.maxBatchQueueSize, equals(3));
      expect(service.maxResolutionHeight, equals(1080));
    });

    test('Lemon Squeezy checkout URL is valid HTTPS', () {
      expect(LicenseService.checkoutUrl.startsWith('https://'), isTrue);
      expect(LicenseService.checkoutUrl.contains('lemonsqueezy.com'), isTrue);
    });

    test('Offline Dev Key activation and deactivation flow', () async {
      final service = LicenseService();
      await service.initialize();
      expect(service.isPro, isFalse);

      final devKey = LicenseService.generateValidDevKey();
      final result = await service.activateKey(devKey);
      expect(result.success, isTrue);
      expect(service.isPro, isTrue);
      expect(service.maxResolutionHeight, equals(2160)); // 4K unlocked

      await service.deactivate();
      expect(service.isPro, isFalse);
      expect(service.maxResolutionHeight, equals(1080)); // Reverted to Free
    });
  });
}
