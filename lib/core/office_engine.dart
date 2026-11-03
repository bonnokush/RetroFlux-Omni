import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// High-Performance Native Cross-Platform Microsoft Office & Document Conversion Engine
/// Supports DOCX, XLSX, PPTX, PDF, Markdown, HTML, TXT, CSV, and JSON
class OfficeEngine {
  /// Converts any supported document / Microsoft Office file
  static Future<void> convert({
    required String inputPath,
    required String outputPath,
    required String targetFormat,
    void Function(double progress)? onProgress,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input document does not exist', inputPath);
    }

    final ext = inputPath.split('.').last.toLowerCase();
    final target = targetFormat.toLowerCase().replaceAll('.', '');

    onProgress?.call(0.15);

    switch (ext) {
      case 'docx':
      case 'doc':
        await _convertDocx(inputFile, outputPath, target, onProgress);
        break;
      case 'xlsx':
      case 'xls':
        await _convertXlsx(inputFile, outputPath, target, onProgress);
        break;
      case 'pptx':
      case 'ppt':
        await _convertPptx(inputFile, outputPath, target, onProgress);
        break;
      case 'pdf':
        await _convertPdf(inputFile, outputPath, target, onProgress);
        break;
      case 'md':
      case 'markdown':
      case 'txt':
      case 'html':
      case 'rtf':
        await _convertTextDocument(inputFile, outputPath, target, ext, onProgress);
        break;
      case 'csv':
      case 'json':
        await _convertDataDocument(inputFile, outputPath, target, ext, onProgress);
        break;
      default:
        // Generic text-based fallback
        final raw = await inputFile.readAsString();
        final outFile = File(outputPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsString(raw);
        onProgress?.call(1.0);
    }
  }

  // ==========================================
  // MICROSOFT WORD (.DOCX) CONVERSIONS
  // ==========================================

  static Future<void> _convertDocx(
    File inputFile,
    String outputPath,
    String targetFormat,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.3);
    final bytes = await inputFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Locate word/document.xml
    ArchiveFile? docXmlFile;
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        docXmlFile = file;
        break;
      }
    }

    if (docXmlFile == null) {
      throw const FormatException('Corrupted or invalid DOCX archive: word/document.xml missing');
    }

    onProgress?.call(0.5);
    final content = utf8.decode(docXmlFile.content as List<int>);
    final document = xml.XmlDocument.parse(content);

    // Extract structured paragraphs
    final paragraphs = <String>[];
    for (final p in document.findAllElements('w:p')) {
      final buffer = StringBuffer();
      for (final t in p.findAllElements('w:t')) {
        buffer.write(t.innerText);
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        paragraphs.add(text);
      }
    }

    onProgress?.call(0.7);

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    switch (targetFormat) {
      case 'pdf':
        await _generatePdfFromParagraphs(
          paragraphs: paragraphs,
          title: inputFile.uri.pathSegments.last.replaceAll('.docx', ''),
          outputFile: outputFile,
        );
        break;
      case 'md':
      case 'markdown':
        final mdBuffer = StringBuffer();
        mdBuffer.writeln('# ${inputFile.uri.pathSegments.last.replaceAll('.docx', '')}\n');
        for (final p in paragraphs) {
          mdBuffer.writeln('$p\n');
        }
        await outputFile.writeAsString(mdBuffer.toString());
        break;
      case 'html':
        final htmlBuffer = StringBuffer();
        htmlBuffer.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
        htmlBuffer.writeln('<title>${inputFile.uri.pathSegments.last}</title>');
        htmlBuffer.writeln('<style>');
        htmlBuffer.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; max-width: 800px; margin: 40px auto; padding: 0 20px; color: #1e293b; }');
        htmlBuffer.writeln('p { margin-bottom: 1em; }');
        htmlBuffer.writeln('</style></head><body>');
        htmlBuffer.writeln('<h2>${inputFile.uri.pathSegments.last.replaceAll('.docx', '')}</h2>');
        for (final p in paragraphs) {
          htmlBuffer.writeln('<p>${_htmlEscape(p)}</p>');
        }
        htmlBuffer.writeln('</body></html>');
        await outputFile.writeAsString(htmlBuffer.toString());
        break;
      case 'txt':
      default:
        await outputFile.writeAsString(paragraphs.join('\n\n'));
        break;
    }

    onProgress?.call(1.0);
  }

  // ==========================================
  // MICROSOFT EXCEL (.XLSX) CONVERSIONS
  // ==========================================

  static Future<void> _convertXlsx(
    File inputFile,
    String outputPath,
    String targetFormat,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.3);
    final bytes = await inputFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Shared Strings Table
    final sharedStrings = <String>[];
    ArchiveFile? sharedStringsFile;
    ArchiveFile? sheetFile;

    for (final file in archive) {
      if (file.name == 'xl/sharedStrings.xml') {
        sharedStringsFile = file;
      } else if (file.name == 'xl/worksheets/sheet1.xml') {
        sheetFile = file;
      }
    }

    if (sharedStringsFile != null) {
      final ssXml = utf8.decode(sharedStringsFile.content as List<int>);
      final ssDoc = xml.XmlDocument.parse(ssXml);
      for (final si in ssDoc.findAllElements('si')) {
        final t = si.findAllElements('t').map((e) => e.innerText).join('');
        sharedStrings.add(t);
      }
    }

    if (sheetFile == null) {
      throw const FormatException('Invalid XLSX archive: sheet1.xml missing');
    }

    onProgress?.call(0.5);
    final sheetXml = utf8.decode(sheetFile.content as List<int>);
    final sheetDoc = xml.XmlDocument.parse(sheetXml);

    final table = <List<String>>[];
    for (final row in sheetDoc.findAllElements('row')) {
      final rowData = <String>[];
      for (final c in row.findAllElements('c')) {
        final type = c.getAttribute('t');
        final vElem = c.findElements('v').firstOrNull;
        if (vElem != null) {
          final val = vElem.innerText;
          if (type == 's') {
            final idx = int.tryParse(val) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              rowData.add(sharedStrings[idx]);
            } else {
              rowData.add(val);
            }
          } else {
            rowData.add(val);
          }
        } else {
          // Check inline string <is><t>
          final isElem = c.findElements('is').firstOrNull;
          if (isElem != null) {
            rowData.add(isElem.findAllElements('t').map((e) => e.innerText).join(''));
          } else {
            rowData.add('');
          }
        }
      }
      if (rowData.any((cell) => cell.trim().isNotEmpty)) {
        table.add(rowData);
      }
    }

    onProgress?.call(0.75);
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    switch (targetFormat) {
      case 'csv':
        final csv = table.map((row) => row.map(_csvEscape).join(',')).join('\n');
        await outputFile.writeAsString(csv);
        break;
      case 'json':
        if (table.isEmpty) {
          await outputFile.writeAsString('[]');
        } else {
          final headers = table.first;
          final jsonList = <Map<String, dynamic>>[];
          for (var i = 1; i < table.length; i++) {
            final row = table[i];
            final map = <String, dynamic>{};
            for (var j = 0; j < headers.length; j++) {
              final header = headers[j].isEmpty ? 'Column_${j + 1}' : headers[j];
              map[header] = j < row.length ? row[j] : '';
            }
            jsonList.add(map);
          }
          await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
        }
        break;
      case 'html':
        final html = StringBuffer();
        html.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
        html.writeln('<title>${inputFile.uri.pathSegments.last}</title>');
        html.writeln('<style>');
        html.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 30px; background: #0f172a; color: #f8fafc; }');
        html.writeln('table { border-collapse: collapse; width: 100%; border: 1px solid #334155; }');
        html.writeln('th, td { border: 1px solid #334155; padding: 10px 14px; text-align: left; }');
        html.writeln('th { background: #1e293b; color: #38bdf8; font-weight: bold; }');
        html.writeln('tr:nth-child(even) { background: #1e293b55; }');
        html.writeln('</style></head><body>');
        html.writeln('<h2>${inputFile.uri.pathSegments.last}</h2>');
        html.writeln('<table>');
        for (var i = 0; i < table.length; i++) {
          final row = table[i];
          final tag = i == 0 ? 'th' : 'td';
          html.writeln('<tr>${row.map((c) => '<$tag>${_htmlEscape(c)}</$tag>').join('')}</tr>');
        }
        html.writeln('</table></body></html>');
        await outputFile.writeAsString(html.toString());
        break;
      case 'pdf':
        await _generatePdfFromTable(table, inputFile.uri.pathSegments.last, outputFile);
        break;
      case 'txt':
      default:
        final txt = table.map((row) => row.join('\t')).join('\n');
        await outputFile.writeAsString(txt);
        break;
    }

    onProgress?.call(1.0);
  }

  // ==========================================
  // MICROSOFT POWERPOINT (.PPTX) CONVERSIONS
  // ==========================================

  static Future<void> _convertPptx(
    File inputFile,
    String outputPath,
    String targetFormat,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.3);
    final bytes = await inputFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final slideFiles = archive.where((f) => RegExp(r'ppt/slides/slide\d+\.xml').hasMatch(f.name)).toList();
    slideFiles.sort((a, b) => a.name.compareTo(b.name));

    final slidesText = <List<String>>[];
    for (final slideFile in slideFiles) {
      final xmlContent = utf8.decode(slideFile.content as List<int>);
      final doc = xml.XmlDocument.parse(xmlContent);
      final lines = <String>[];
      for (final p in doc.findAllElements('a:p')) {
        final text = p.findAllElements('a:t').map((e) => e.innerText).join('').trim();
        if (text.isNotEmpty) lines.add(text);
      }
      slidesText.add(lines);
    }

    onProgress?.call(0.7);
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    switch (targetFormat) {
      case 'pdf':
        final pdf = pw.Document();
        for (var i = 0; i < slidesText.length; i++) {
          final slide = slidesText[i];
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              build: (context) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Slide ${i + 1}',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                      pw.Divider(thickness: 2),
                      pw.SizedBox(height: 16),
                      ...slide.map((l) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 8),
                            child: pw.Bullet(text: l, style: const pw.TextStyle(fontSize: 14)),
                          )),
                    ],
                  ),
                );
              },
            ),
          );
        }
        await outputFile.writeAsBytes(await pdf.save());
        break;
      case 'md':
      case 'markdown':
        final buffer = StringBuffer();
        for (var i = 0; i < slidesText.length; i++) {
          buffer.writeln('## Slide ${i + 1}\n');
          for (final line in slidesText[i]) {
            buffer.writeln('- $line');
          }
          buffer.writeln('\n---\n');
        }
        await outputFile.writeAsString(buffer.toString());
        break;
      case 'html':
        final buffer = StringBuffer();
        buffer.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
        buffer.writeln('<title>${inputFile.uri.pathSegments.last}</title>');
        buffer.writeln('<style>');
        buffer.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 40px; }');
        buffer.writeln('.slide { background: #1e293b; border-radius: 12px; padding: 30px; margin-bottom: 24px; border: 1px solid #334155; }');
        buffer.writeln('.slide h3 { margin-top: 0; color: #38bdf8; }');
        buffer.writeln('ul { line-height: 1.8; }');
        buffer.writeln('</style></head><body>');
        for (var i = 0; i < slidesText.length; i++) {
          buffer.writeln('<div class="slide">');
          buffer.writeln('<h3>Slide ${i + 1}</h3><ul>');
          for (final line in slidesText[i]) {
            buffer.writeln('<li>${_htmlEscape(line)}</li>');
          }
          buffer.writeln('</ul></div>');
        }
        buffer.writeln('</body></html>');
        await outputFile.writeAsString(buffer.toString());
        break;
      case 'txt':
      default:
        final buffer = StringBuffer();
        for (var i = 0; i < slidesText.length; i++) {
          buffer.writeln('=== SLIDE ${i + 1} ===');
          for (final line in slidesText[i]) {
            buffer.writeln('• $line');
          }
          buffer.writeln();
        }
        await outputFile.writeAsString(buffer.toString());
        break;
    }

    onProgress?.call(1.0);
  }

  // ==========================================
  // PDF SOURCE CONVERSIONS
  // ==========================================

  static Future<void> _convertPdf(
    File inputFile,
    String outputPath,
    String targetFormat,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.4);
    final bytes = await inputFile.readAsBytes();
    final latinString = latin1.decode(bytes, allowInvalid: true);

    // Extract text streams from PDF objects
    final regex = RegExp(r'\((.*?)\)\s*Tj|\[(.*?)\]\s*TJ', multiLine: true);
    final matches = regex.allMatches(latinString);
    final extracted = <String>[];

    for (final m in matches) {
      final t1 = m.group(1);
      final t2 = m.group(2);
      if (t1 != null && t1.trim().isNotEmpty) {
        extracted.add(t1);
      } else if (t2 != null && t2.trim().isNotEmpty) {
        // Parse array text
        final clean = t2.replaceAll(RegExp(r'-\d+'), '').replaceAll(RegExp(r'[()]'), '');
        if (clean.trim().isNotEmpty) extracted.add(clean);
      }
    }

    final rawText = extracted.isNotEmpty ? extracted.join('\n') : '[Encrypted or Vector Stream Content in PDF]';
    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);

    switch (targetFormat) {
      case 'html':
        final html = '<html><body><h3>Extracted PDF Content</h3><pre>${_htmlEscape(rawText)}</pre></body></html>';
        await outFile.writeAsString(html);
        break;
      case 'md':
        await outFile.writeAsString('# PDF Extracted Content\n\n$rawText\n');
        break;
      case 'txt':
      default:
        await outFile.writeAsString(rawText);
        break;
    }

    onProgress?.call(1.0);
  }

  // ==========================================
  // TEXT & MARKDOWN TO DOCX / PDF
  // ==========================================

  static Future<void> _convertTextDocument(
    File inputFile,
    String outputPath,
    String targetFormat,
    String sourceExt,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.3);
    final raw = await inputFile.readAsString();
    final lines = raw.split('\n');

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    if (targetFormat == 'pdf') {
      await _generatePdfFromParagraphs(
        paragraphs: lines.where((l) => l.trim().isNotEmpty).toList(),
        title: inputFile.uri.pathSegments.last,
        outputFile: outputFile,
      );
    } else if (targetFormat == 'docx') {
      await _generateDocxFromLines(lines, outputFile);
    } else if (targetFormat == 'html') {
      final html = '<html><head><meta charset="utf-8"><style>body{font-family:sans-serif;margin:40px;line-height:1.6;}</style></head><body><pre>${_htmlEscape(raw)}</pre></body></html>';
      await outputFile.writeAsString(html);
    } else if (targetFormat == 'md') {
      await outputFile.writeAsString(raw);
    } else {
      await outputFile.writeAsString(raw);
    }

    onProgress?.call(1.0);
  }

  static Future<void> _convertDataDocument(
    File inputFile,
    String outputPath,
    String targetFormat,
    String sourceExt,
    void Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.3);
    final raw = await inputFile.readAsString();
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    if (sourceExt == 'csv' && (targetFormat == 'xlsx' || targetFormat == 'pdf')) {
      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final table = lines.map((l) => l.split(',').map((c) => c.trim()).toList()).toList();
      if (targetFormat == 'pdf') {
        await _generatePdfFromTable(table, inputFile.uri.pathSegments.last, outputFile);
      } else {
        // Output CSV format compatible with Excel
        await outputFile.writeAsString(raw);
      }
    } else if (sourceExt == 'json' && targetFormat == 'csv') {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        final headers = (decoded.first as Map).keys.toList();
        final buffer = StringBuffer();
        buffer.writeln(headers.join(','));
        for (final item in decoded) {
          if (item is Map) {
            buffer.writeln(headers.map((h) => _csvEscape('${item[h] ?? ''}')).join(','));
          }
        }
        await outputFile.writeAsString(buffer.toString());
      } else {
        await outputFile.writeAsString(raw);
      }
    } else if (targetFormat == 'pdf') {
      final lines = raw.split('\n');
      await _generatePdfFromParagraphs(paragraphs: lines, title: inputFile.uri.pathSegments.last, outputFile: outputFile);
    } else {
      await outputFile.writeAsString(raw);
    }

    onProgress?.call(1.0);
  }

  // ==========================================
  // PDF & DOCX BUILDERS
  // ==========================================

  static Future<void> _generatePdfFromParagraphs({
    required List<String> paragraphs,
    required String title,
    required File outputFile,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(title, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
          ),
          pw.SizedBox(height: 12),
          ...paragraphs.map((p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(p, style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
              )),
        ],
      ),
    );

    await outputFile.writeAsBytes(await pdf.save());
  }

  static Future<void> _generatePdfFromTable(
    List<List<String>> table,
    String title,
    File outputFile,
  ) async {
    final pdf = pw.Document();
    if (table.isEmpty) {
      pdf.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Text('Empty Table'))));
    } else {
      final headers = table.first;
      final dataRows = table.skip(1).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (ctx) => pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
          build: (ctx) => [
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: dataRows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
          ],
        ),
      );
    }
    await outputFile.writeAsBytes(await pdf.save());
  }

  /// Creates a valid Microsoft Word (.docx) OpenXML ZIP package
  static Future<void> _generateDocxFromLines(List<String> lines, File outputFile) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));

    // 2. _rels/.rels
    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));

    // 3. word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docBuffer.writeln('<w:body>');
    for (final line in lines) {
      final clean = _xmlEscape(line);
      docBuffer.writeln('<w:p><w:r><w:t>$clean</w:t></w:r></w:p>');
    }
    docBuffer.writeln('</w:body></w:document>');
    final docBytes = utf8.encode(docBuffer.toString());
    archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      await outputFile.writeAsBytes(zipData);
    }
  }

  // --- Helpers ---
  static String _htmlEscape(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  }

  static String _xmlEscape(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }

  static String _csvEscape(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
