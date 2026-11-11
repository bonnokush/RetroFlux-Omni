import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retroflux_omni/core/theme_controller.dart';
import 'package:retroflux_omni/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Google Pixel Material You Dynamic Theming Tests', () {
    test(
        '1. ThemeController initializes with default Lavender and updates seeds',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(themeControllerProvider);
      expect(settings.seedColor, equals(PixelSeeds.obsidianLavender));
      expect(settings.themeMode, equals(ThemeMode.dark));
      expect(settings.useSystemWallpaper, isFalse);

      final notifier = container.read(themeControllerProvider.notifier);
      await notifier.setSeedColor(PixelSeeds.bayBlue);

      final updated = container.read(themeControllerProvider);
      expect(updated.seedColor, equals(PixelSeeds.bayBlue));

      await notifier.toggleSystemWallpaper(true);
      expect(
          container.read(themeControllerProvider).useSystemWallpaper, isTrue);

      await notifier.setThemeMode(ThemeMode.light);
      expect(container.read(themeControllerProvider).themeMode,
          equals(ThemeMode.light));
    });

    testWidgets('2. Open Palette Switcher and verify Pixel Seeds',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: RetroFluxOmniApp()));
      await tester.pumpAndSettle();

      // Tap Palette Switcher icon button in top right header
      final paletteBtn = find.byTooltip('Material You Palette').first;
      expect(paletteBtn, findsOneWidget);
      await tester.tap(paletteBtn);
      await tester.pumpAndSettle();

      // Verify Palette Switcher sheet contents
      expect(find.text('Material You Palette'), findsOneWidget);
      expect(find.text('Dynamic System Wallpaper'), findsOneWidget);
      expect(find.text('Google Pixel Color Seeds'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      // Verify tooltips for all 5 Pixel Seeds
      expect(find.byTooltip('Bay Blue'), findsOneWidget);
      expect(find.byTooltip('Sage Green'), findsOneWidget);
      expect(find.byTooltip('Lavender'), findsOneWidget);
      expect(find.byTooltip('Terracotta'), findsOneWidget);
      expect(find.byTooltip('Amber Gold'), findsOneWidget);
    });
  });
}
