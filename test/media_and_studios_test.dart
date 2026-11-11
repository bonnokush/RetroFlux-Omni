import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retroflux_omni/main.dart';
import 'package:retroflux_omni/core/engine_bridge.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dedicated 4K Media Studio & Image Studio Tests', () {
    testWidgets('1. Navigate into 4K Media Studio and Verify Controls', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: RetroFluxOmniApp()));
      await tester.pumpAndSettle();

      // Tap '4K Media Studio' in the sidebar
      final mediaNav = find.text('4K Media Studio');
      expect(mediaNav, findsOneWidget);
      await tester.tap(mediaNav);
      await tester.pumpAndSettle();

      // Verify 4K Media Studio elements
      expect(find.text('4K Video & Audio Media Studio'), findsOneWidget);
      expect(find.text('Add Media Files'), findsOneWidget);
      expect(find.text('Lossless Remux (-c copy): '), findsOneWidget);
      expect(find.text('MP4'), findsOneWidget);
      expect(find.text('MKV'), findsOneWidget);
      expect(find.text('MOV'), findsOneWidget);
      expect(find.text('MP3'), findsOneWidget);
    });

    testWidgets('2. Navigate into Image Studio', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: RetroFluxOmniApp()));
      await tester.pumpAndSettle();

      // Tap 'Image Tools'
      final imageNav = find.text('Image Tools');
      await tester.tap(imageNav);
      await tester.pumpAndSettle();

      expect(find.text('Image Studio & Compressor'), findsOneWidget);
      expect(find.text('Add Images'), findsOneWidget);
    });

    test('3. EngineBridge Hardware Capability Detection Test', () async {
      final ffmpegPath = await EngineBridge.resolveFfmpegPath();
      // On Windows development machine, ffmpeg path is resolved from winget or PATH
      if (ffmpegPath != null) {
        final caps = await EngineBridge.detectGpuCapabilities(ffmpegPath);
        expect(caps.preferredVendorLabel.isNotEmpty, isTrue);
      }
    });
  });
}
