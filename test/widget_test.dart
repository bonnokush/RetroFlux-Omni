import 'package:flutter_test/flutter_test.dart';
import 'package:retroflux_omni/core/license_service.dart';

void main() {
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
  });
}
