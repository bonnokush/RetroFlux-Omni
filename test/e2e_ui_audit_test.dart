import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retroflux_omni/main.dart';
import 'package:retroflux_omni/ui/dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RetroFlux-Omni End-to-End Automated UI & Behavior Audit', () {
    testWidgets('1. Launch & Render Tree Integrity Test',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: RetroFluxOmniApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert zero boot crashes and all core brand anchors exist
      expect(find.text('RETROFLUX'), findsOneWidget);
      expect(find.text('OMNI 4.0 PRO'), findsOneWidget);
      expect(find.text('Universal Conversion Engine'), findsOneWidget);
      expect(find.text('PRO UNLIMITED'), findsOneWidget);
      expect(find.text('Queue is empty'), findsOneWidget);
    });

    testWidgets('2. Sidebar Navigation and View Switching Audit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: RetroFluxOmniApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Click 'Image Tools' nav button
      final imageNav = find.text('Image Tools');
      expect(imageNav, findsOneWidget);
      await tester.tap(imageNav);
      await tester.pumpAndSettle();

      // Click '4K Media Studio' nav button
      final mediaNav = find.text('4K Media Studio');
      expect(mediaNav, findsOneWidget);
      await tester.tap(mediaNav);
      await tester.pumpAndSettle();

      // Click 'Conversion History' nav button
      final historyNav = find.text('Conversion History');
      expect(historyNav, findsOneWidget);
      await tester.tap(historyNav);
      await tester.pumpAndSettle();

      // Return to 'Batch Queue'
      final batchNav = find.text('Batch Queue');
      expect(batchNav, findsOneWidget);
      await tester.tap(batchNav);
      await tester.pumpAndSettle();
    });

    testWidgets('3. Microsoft Store Edition Unlimited Batch Queue Audit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RetroFluxOmniApp(),
        ),
      );
      await tester.pumpAndSettle();

      // In Microsoft Store Edition, all 5 files are accepted immediately without arbitrary caps
      final notifier = container.read(taskQueueProvider.notifier);
      await notifier.addFiles([
        'C:/mock/video1.mp4',
        'C:/mock/video2.mp4',
        'C:/mock/image3.png',
        'C:/mock/document4.json',
        'C:/mock/audio5.wav',
      ]);
      await tester.pumpAndSettle();

      // Assert all 5 files in queue
      final tasks = container.read(taskQueueProvider);
      expect(tasks.length, equals(5));
      expect(find.text('video1.mp4'), findsOneWidget);
      expect(find.text('video2.mp4'), findsOneWidget);
      expect(find.text('image3.png'), findsOneWidget);
      expect(find.text('document4.json'), findsOneWidget);
      expect(find.text('audio5.wav'), findsOneWidget);
      expect(find.textContaining('Queue: 5 items'), findsOneWidget);
    });

    testWidgets('4. PRO Status Dialog & Microsoft Store Verification Audit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RetroFluxOmniApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PRO license card is active in sidebar
      final proCard = find.text('PRO ACTIVE');
      expect(proCard, findsOneWidget);
      await tester.tap(proCard);
      await tester.pumpAndSettle();

      // Verify PRO modal opened cleanly
      expect(find.text('RETROFLUX PRO 4.0'), findsOneWidget);
      expect(find.text('Full Lifetime Access Unlocked'), findsOneWidget);
      expect(find.text('4K Ultra HD Export (Up to 2160p 60FPS)'), findsOneWidget);

      // Close modal
      final doneBtn = find.text('DONE');
      expect(doneBtn, findsOneWidget);
      await tester.tap(doneBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('5. Mobile Responsive Layout Transition Audit',
        (WidgetTester tester) async {
      // Simulate mobile portrait dimensions (390x844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: RetroFluxOmniApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify desktop sidebar is hidden and mobile AppBar + BottomNavigationBar are rendered
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('RetroFlux Omni 4.0'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('4K Media'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });
  });
}
