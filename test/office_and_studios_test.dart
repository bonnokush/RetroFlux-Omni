import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retroflux_omni/main.dart';
import 'package:retroflux_omni/core/office_engine.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dedicated Studios & Microsoft Office Conversion Tests', () {
    testWidgets('1. Navigate into Docs & Office Studio and Verify Presets', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: RetroFluxOmniApp()));
      await tester.pumpAndSettle();

      // Tap 'Docs & Office' in the sidebar
      final docsNav = find.text('Docs & Office');
      expect(docsNav, findsOneWidget);
      await tester.tap(docsNav);
      await tester.pumpAndSettle();

      // Verify Microsoft Office Studio elements
      expect(find.text('Microsoft Office & Docs Studio'), findsOneWidget);
      expect(find.text('Word (.docx)'), findsOneWidget);
      expect(find.text('Excel (.xlsx)'), findsOneWidget);
      expect(find.text('PowerPoint'), findsOneWidget);
      expect(find.text('PDF Document'), findsOneWidget);
      expect(find.text('Add Documents'), findsOneWidget);
    });

    testWidgets('2. Navigate into Media Studio and Image Studio', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: RetroFluxOmniApp()));
      await tester.pumpAndSettle();

      // Tap 'Media Engine'
      final mediaNav = find.text('Media Engine');
      await tester.tap(mediaNav);
      await tester.pumpAndSettle();

      expect(find.text('Video & Audio Media Studio'), findsOneWidget);
      expect(find.text('Add Media Files'), findsOneWidget);

      // Tap 'Image Tools'
      final imageNav = find.text('Image Tools');
      await tester.tap(imageNav);
      await tester.pumpAndSettle();

      expect(find.text('Image Studio & Compressor'), findsOneWidget);
      expect(find.text('Add Images'), findsOneWidget);
    });

    test('3. OfficeEngine Text & Data to PDF / Document Processing', () async {
      final tempDir = await Directory.systemTemp.createTemp('retroflux_test_');
      try {
        // Create mock markdown document
        final sampleMd = File('${tempDir.path}/test_doc.md');
        await sampleMd.writeAsString('# Executive Summary\n\nRetroFlux Omni 4.0 cross-platform converter.\n');

        // Convert to PDF
        final outPdf = '${tempDir.path}/test_doc.pdf';
        await OfficeEngine.convert(
          inputPath: sampleMd.path,
          outputPath: outPdf,
          targetFormat: 'pdf',
        );

        expect(File(outPdf).existsSync(), isTrue);
        expect(await File(outPdf).length(), greaterThan(100));

        // Convert to DOCX OpenXML package
        final outDocx = '${tempDir.path}/test_doc.docx';
        await OfficeEngine.convert(
          inputPath: sampleMd.path,
          outputPath: outDocx,
          targetFormat: 'docx',
        );

        expect(File(outDocx).existsSync(), isTrue);
        expect(await File(outDocx).length(), greaterThan(100));

        // Read DOCX back and convert to HTML
        final outHtml = '${tempDir.path}/test_doc.html';
        await OfficeEngine.convert(
          inputPath: outDocx,
          outputPath: outHtml,
          targetFormat: 'html',
        );

        expect(File(outHtml).existsSync(), isTrue);
        final htmlContent = await File(outHtml).readAsString();
        expect(htmlContent.contains('Executive Summary'), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
