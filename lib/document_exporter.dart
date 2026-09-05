import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

import 'models.dart';
import 'internal_links.dart';

enum ManuscriptFormat {
  markdown('Markdown', 'md', 'Editable Markdown manuscript'),
  epub('EPUB', 'epub', 'Reflowable e-book package'),
  fb2('FictionBook 2', 'fb2', 'XML e-book format popular with Russian readers'),
  pdf('PDF', 'pdf', 'Print-ready 6 × 9 inch manuscript'),
  html('HTML', 'html', 'Self-contained page for web reading'),
  odt('OpenDocument Text', 'odt', 'Editable document for LibreOffice and Word'),
  text('Plain text', 'txt', 'Maximum compatibility');

  const ManuscriptFormat(this.label, this.extension, this.description);
  final String label;
  final String extension;
  final String description;
}

class DocumentExporter {
  static Future<Uint8List> build(
    StoryProject project,
    ManuscriptFormat format,
  ) => switch (format) {
    ManuscriptFormat.markdown => Future.value(
      Uint8List.fromList(utf8.encode(_markdown(project))),
    ),
    ManuscriptFormat.text => Future.value(
      Uint8List.fromList(utf8.encode(_plainText(project))),
    ),
    ManuscriptFormat.html => Future.value(
      Uint8List.fromList(utf8.encode(_html(project))),
    ),
    ManuscriptFormat.fb2 => Future.value(
      Uint8List.fromList(utf8.encode(_fb2(project))),
    ),
    ManuscriptFormat.epub => Future.value(_epub(project)),
    ManuscriptFormat.odt => Future.value(_odt(project)),
    ManuscriptFormat.pdf => _pdf(project),
  };

  static String _markdown(StoryProject project, {bool webLinks = false}) {
    final out = StringBuffer('# ${project.title}\n\n');
    final sceneIds = project.sections
        .expand((section) => section.scenes)
        .map((scene) => scene.id)
        .toSet();
    if (project.author.isNotEmpty) out.writeln('*${project.author}*\n');
    for (final section in project.sections) {
      out.writeln('## ${section.title}\n');
      for (final scene in section.scenes) {
        if (webLinks) {
          out.writeln('<a id="${InternalLinks.anchor(scene.id)}"></a>');
        }
        out.writeln('### ${scene.title}\n');
        final content = webLinks
            ? InternalLinks.resolveForWeb(scene.content, sceneIds)
            : scene.content;
        out.writeln('${content.trim()}\n\n---\n');
      }
    }
    return out.toString().trimRight();
  }

  static String _plainText(StoryProject project) {
    final source = _markdown(project)
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^---$', multiLine: true), '* * *')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'[*_`]'), '');
    return source;
  }

  static String _html(StoryProject project) =>
      '''<!doctype html>
<html lang="${_xml(project.language)}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_xml(project.title)}</title><style>
body{max-width:44rem;margin:3rem auto;padding:0 1.3rem;font:18px/1.65 Georgia,serif;color:#26251f;background:#f8f6f0}h1,h2,h3{line-height:1.2}hr{border:0;border-top:1px solid #ccc;margin:2.5rem 0}blockquote{border-left:3px solid #668071;padding-left:1rem;color:#536158}code{background:#eae7de;padding:.1rem .3rem}
</style></head><body>${project.coverImage == null ? "" : '<img alt="Cover" style="max-width:100%;max-height:90vh" src="data:image/png;base64,${project.coverImage}"/>'}${md.markdownToHtml(_markdown(project, webLinks: true))}</body></html>''';

  static String _fb2(StoryProject project) {
    final body = StringBuffer();
    for (final section in project.sections) {
      body.write('<section><title><p>${_xml(section.title)}</p></title>');
      for (final scene in section.scenes) {
        body.write('<section><title><p>${_xml(scene.title)}</p></title>');
        for (final paragraph in _paragraphs(scene.content)) {
          body.write('<p>${_xml(_plainMarkdown(paragraph))}</p>');
        }
        body.write('</section>');
      }
      body.write('</section>');
    }
    return '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink"><description><title-info><genre>prose</genre><author><nickname>${_xml(project.author)}</nickname></author><book-title>${_xml(project.title)}</book-title>${project.coverImage == null ? "" : '<coverpage><image l:href="#cover"/></coverpage>'}<lang>${_xml(project.language)}</lang></title-info></description><body><title><p>${_xml(project.title)}</p></title>$body</body>${project.coverImage == null ? "" : '<binary id="cover" content-type="image/png">${project.coverImage}</binary>'}</FictionBook>''';
  }

  static Uint8List _epub(StoryProject project) {
    final archive = Archive();
    final mime = ArchiveFile(
      'mimetype',
      20,
      utf8.encode('application/epub+zip'),
    )..compression = CompressionType.none;
    archive.addFile(mime);
    if (project.coverImage != null) {
      final bytes = base64Decode(project.coverImage!);
      archive.addFile(ArchiveFile('OEBPS/cover.png', bytes.length, bytes));
      _addText(
        archive,
        'OEBPS/cover.xhtml',
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Cover</title></head><body><img src="cover.png" alt="Cover" style="max-width:100%"/></body></html>',
      );
    }

    _addText(
      archive,
      'META-INF/container.xml',
      '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''',
    );
    _addText(
      archive,
      'OEBPS/book.xhtml',
      '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" lang="${_xml(project.language)}"><head><title>${_xml(project.title)}</title><link rel="stylesheet" href="style.css" type="text/css"/></head><body>${md.markdownToHtml(_markdown(project, webLinks: true))}</body></html>''',
    );
    _addText(
      archive,
      'OEBPS/style.css',
      'body{font-family:serif;line-height:1.5}h1,h2,h3{page-break-after:avoid}',
    );
    _addText(
      archive,
      'OEBPS/content.opf',
      '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:uuid:${_xml(project.id)}</dc:identifier><dc:title>${_xml(project.title)}</dc:title><dc:creator>${_xml(project.author)}</dc:creator><dc:language>${_xml(project.language)}</dc:language></metadata><manifest>${project.coverImage == null ? "" : '<item id="cover-image" href="cover.png" media-type="image/png" properties="cover-image"/><item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>'}<item id="book" href="book.xhtml" media-type="application/xhtml+xml"/><item id="css" href="style.css" media-type="text/css"/></manifest><spine>${project.coverImage == null ? "" : '<itemref idref="cover"/>'}<itemref idref="book"/></spine></package>''',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Uint8List _odt(StoryProject project) {
    final archive = Archive();
    final mime = utf8.encode('application/vnd.oasis.opendocument.text');
    archive.addFile(
      ArchiveFile('mimetype', mime.length, mime)
        ..compression = CompressionType.none,
    );
    if (project.coverImage != null) {
      final bytes = base64Decode(project.coverImage!);
      archive.addFile(ArchiveFile('Pictures/cover.png', bytes.length, bytes));
    }
    final content = StringBuffer();
    if (project.coverImage != null) {
      final header = ByteData.sublistView(base64Decode(project.coverImage!));
      final ratio = header.getUint32(16) / header.getUint32(20);
      final width = ratio >= 4.5 / 6.5 ? 4.5 : 6.5 * ratio;
      final height = ratio >= 4.5 / 6.5 ? 4.5 / ratio : 6.5;
      content.write(
        '<text:p><draw:frame draw:name="Cover" text:anchor-type="as-char" svg:width="${width}in" svg:height="${height}in"><draw:image xlink:href="Pictures/cover.png" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad"/></draw:frame></text:p>',
      );
    }
    content.write(
      '<text:h text:outline-level="1">${_xml(project.title)}</text:h>',
    );
    if (project.author.isNotEmpty) {
      content.write('<text:p>${_xml(project.author)}</text:p>');
    }
    for (final section in project.sections) {
      content.write(
        '<text:h text:outline-level="2">${_xml(section.title)}</text:h>',
      );
      for (final scene in section.scenes) {
        content.write(
          '<text:h text:outline-level="3">${_xml(scene.title)}</text:h>',
        );
        for (final paragraph in _paragraphs(scene.content)) {
          content.write('<text:p>${_xml(_plainMarkdown(paragraph))}</text:p>');
        }
      }
    }
    _addText(
      archive,
      'content.xml',
      '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" office:version="1.3"><office:body><office:text>$content</office:text></office:body></office:document-content>''',
    );
    _addText(
      archive,
      'META-INF/manifest.xml',
      '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3"><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>${project.coverImage == null ? "" : '<manifest:file-entry manifest:full-path="Pictures/cover.png" manifest:media-type="image/png"/>'}</manifest:manifest>''',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Future<Uint8List> _pdf(StoryProject project) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSerif-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSerif-Bold.ttf'),
    );
    var pages = <String, int>{};
    for (var pass = 0; pass < 4; pass++) {
      final measured = <String, int>{};
      final trial = _pdfDocument(project, regular, bold, pages, measured);
      await trial.save();
      if (_samePages(pages, measured)) {
        pages = measured;
        break;
      }
      pages = measured;
    }
    final finalPages = <String, int>{};
    final document = _pdfDocument(project, regular, bold, pages, finalPages);
    return document.save();
  }

  static pw.Document _pdfDocument(
    StoryProject project,
    pw.Font regular,
    pw.Font bold,
    Map<String, int> resolvedPages,
    Map<String, int> measuredPages,
  ) {
    final document = pw.Document(title: project.title, author: project.author);
    if (project.coverImage != null) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            6 * PdfPageFormat.inch,
            9 * PdfPageFormat.inch,
          ),
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(base64Decode(project.coverImage!)),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        pageFormat: PdfPageFormat(
          6 * PdfPageFormat.inch,
          9 * PdfPageFormat.inch,
          marginAll: .7 * PdfPageFormat.inch,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${context.pageNumber}'),
        ),
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              project.title,
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (project.author.isNotEmpty)
            pw.Text(project.author, style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 24),
          for (final section in project.sections) ...[
            pw.Header(level: 1, child: pw.Text(section.title)),
            for (final scene in section.scenes) ...[
              _SceneDestination(
                sceneId: scene.id,
                pages: measuredPages,
                child: pw.Header(level: 2, child: pw.Text(scene.title)),
              ),
              for (final paragraph in _paragraphs(scene.content))
                pw.Paragraph(
                  text: _plainMarkdown(
                    InternalLinks.resolveForPrint(paragraph, resolvedPages),
                  ),
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
                ),
              pw.SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
    return document;
  }

  static bool _samePages(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);

  static void _addText(Archive archive, String path, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static Iterable<String> _paragraphs(String value) =>
      value.trim().split(RegExp(r'\n\s*\n'));
  static String _plainMarkdown(String value) => value
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'[*_`]'), '');
  static String _xml(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);
}

class _SceneDestination extends pw.StatelessWidget {
  _SceneDestination({
    required this.sceneId,
    required this.pages,
    required this.child,
  });

  final String sceneId;
  final Map<String, int> pages;
  final pw.Widget child;

  @override
  pw.Widget build(pw.Context context) {
    pages[sceneId] = context.pageNumber;
    return pw.Anchor(name: InternalLinks.anchor(sceneId), child: child);
  }
}
