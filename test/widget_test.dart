import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/commonmark_view.dart';
import 'package:sutoriraita/document_exporter.dart';
import 'package:sutoriraita/entity_detector.dart';
import 'package:sutoriraita/gemmell.dart';
import 'package:sutoriraita/genre_packs.dart';
import 'package:sutoriraita/main.dart';
import 'package:sutoriraita/internal_links.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/project_controller.dart';
import 'package:sutoriraita/project_store.dart';
import 'package:sutoriraita/proofreading.dart';

class _BlockingStore extends ProjectStore {
  _BlockingStore()
    : super(documentsDirectory: () async => Directory.systemTemp);

  final Completer<void> releaseFirstSave = Completer<void>();
  final List<String> savedContents = [];
  final List<DateTime> savedTimestamps = [];

  @override
  Future<void> save(StoryProject project) async {
    savedContents.add(project.sections.first.scenes.first.content);
    savedTimestamps.add(project.sections.first.scenes.first.updatedAt);
    if (savedContents.length == 1) await releaseFirstSave.future;
  }
}

class _NoopStore extends ProjectStore {
  @override
  Future<void> save(StoryProject project) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CommonMark view renders syntax as formatted content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonMarkView(
            data: '**Bold** and *italic*\n\n- one\n- two\n\n> quoted',
          ),
        ),
      ),
    );
    final spans = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .where((text) => text.textSpan != null)
        .expand((text) => _flattenSpans(text.textSpan!))
        .toList();
    final renderedText = spans.map((span) => span.text ?? '').join();
    expect(renderedText, contains('Bold'));
    expect(renderedText, contains('italic'));
    expect(renderedText, contains('quoted'));
    expect(renderedText, isNot(contains('**Bold**')));
    expect(
      spans.any(
        (span) =>
            span.text == 'Bold' && span.style?.fontWeight == FontWeight.w800,
      ),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.text == 'italic' && span.style?.fontStyle == FontStyle.italic,
      ),
      isTrue,
    );
  });

  testWidgets('chapter and scene rename dialogs close without assertions', (
    tester,
  ) async {
    final scene = StoryScene(
      id: 'scene',
      title: 'Old scene',
      content: '',
      updatedAt: DateTime(2026),
    );
    final section = StorySection(
      id: 'section',
      title: 'Old chapter',
      scenes: [scene],
    );
    final controller = ProjectController(_NoopStore())
      ..useProject(
        StoryProject(
          id: 'project',
          title: 'Project',
          author: '',
          language: 'en',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          sections: [section],
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SectionTile(section: section, controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New chapter');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(section.title, 'New chapter');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New scene');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(scene.title, 'New scene');
    expect(tester.takeException(), isNull);
  });

  test('controller can reorder and move scenes without losing content', () {
    final first = StoryScene(
      id: 'one',
      title: 'One',
      content: 'First words',
      updatedAt: DateTime(2026),
    );
    final second = StoryScene(
      id: 'two',
      title: 'Two',
      content: 'Second words',
      updatedAt: DateTime(2026),
    );
    final a = StorySection(id: 'a', title: 'A', scenes: [first, second]);
    final b = StorySection(id: 'b', title: 'B', scenes: []);
    final project = StoryProject(
      id: 'p',
      title: 'Test',
      author: '',
      language: 'en',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sections: [a, b],
    );
    final controller = ProjectController(ProjectStore())..useProject(project);
    controller.reorderScene(a, 0, 1);
    expect(a.scenes.map((scene) => scene.id), ['two', 'one']);
    controller.moveScene(first, b);
    expect(b.scenes.single.content, 'First words');
    controller.dispose();
  });

  test(
    'edits during autosave update timestamps and queue another save',
    () async {
      final scene = StoryScene(
        id: 'scene',
        title: 'Opening',
        content: '',
        updatedAt: DateTime.utc(2026),
      );
      final project = StoryProject(
        id: 'project',
        title: 'Test',
        author: '',
        language: 'en',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        sections: [
          StorySection(id: 'chapter', title: 'One', scenes: [scene]),
        ],
      );
      final store = _BlockingStore();
      final controller = ProjectController(store)..useProject(project);

      controller.updateContent('First edit');
      final firstTimestamp = scene.updatedAt;
      final saving = controller.saveNow();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      controller.updateContent('Second edit while saving');
      final secondTimestamp = scene.updatedAt;
      store.releaseFirstSave.complete();
      await saving;

      expect(secondTimestamp.isAfter(firstTimestamp), isTrue);
      expect(store.savedContents, ['First edit', 'Second edit while saving']);
      expect(store.savedTimestamps, [firstTimestamp, secondTimestamp]);
      expect(controller.saveState, SaveState.saved);
      controller.dispose();
    },
  );

  test('combined exports follow manuscript order', () {
    final project = StoryProject(
      id: 'p',
      title: 'North',
      author: 'A. Writer',
      language: 'en',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sections: [
        StorySection(
          id: 'c',
          title: 'Chapter One',
          scenes: [
            StoryScene(
              id: 's',
              title: 'Arrival',
              content: 'The train stopped.',
              updatedAt: DateTime(2026),
            ),
          ],
        ),
      ],
    );
    final markdown = ProjectStore().combinedManuscript(project, markdown: true);
    expect(markdown, contains('# North'));
    expect(markdown, contains('## Chapter One'));
    expect(markdown, contains('### Arrival'));
    expect(markdown, contains('The train stopped.'));
  });

  test('document exporters produce structurally valid formats', () async {
    final project = StoryProject(
      id: 'export-id',
      title: 'Sutōrīraitā Экспорт',
      author: 'House Raccoon',
      language: 'en',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sections: [
        StorySection(
          id: 'chapter',
          title: 'Chapter One',
          scenes: [
            StoryScene(
              id: 'scene',
              title: 'Opening',
              content: 'A **bold** beginning.\n\nContinue in [the cellar](scene:cellar).',
              updatedAt: DateTime(2026),
            ),
            StoryScene(
              id: 'cellar',
              title: 'The Cellar',
              content: 'A second paragraph.',
              updatedAt: DateTime(2026),
            ),
          ],
        ),
      ],
    );
    final markdown = utf8.decode(
      await DocumentExporter.build(project, ManuscriptFormat.markdown),
    );
    final html = utf8.decode(
      await DocumentExporter.build(project, ManuscriptFormat.html),
    );
    final fb2 = utf8.decode(
      await DocumentExporter.build(project, ManuscriptFormat.fb2),
    );
    final text = utf8.decode(
      await DocumentExporter.build(project, ManuscriptFormat.text),
    );
    final epub = ZipDecoder().decodeBytes(
      await DocumentExporter.build(project, ManuscriptFormat.epub),
    );
    final odt = ZipDecoder().decodeBytes(
      await DocumentExporter.build(project, ManuscriptFormat.odt),
    );
    final pdf = await DocumentExporter.build(project, ManuscriptFormat.pdf);
    if (const bool.fromEnvironment('WRITE_PDF_PREVIEW')) {
      final preview = Directory('tmp/pdfs');
      await preview.create(recursive: true);
      await File('${preview.path}/sutoriraita-export-preview.pdf')
          .writeAsBytes(pdf);
    }

    expect(markdown, contains('**bold**'));
    expect(markdown, contains('[the cellar](scene:cellar)'));
    expect(html, contains('<strong>bold</strong>'));
    expect(html, contains('href="#scene-cellar"'));
    expect(html, contains('id="scene-cellar"'));
    expect(fb2, contains('<FictionBook'));
    expect(text, contains('A bold beginning.'));
    expect(
      epub.files.map((file) => file.name),
      containsAll([
        'mimetype',
        'META-INF/container.xml',
        'OEBPS/content.opf',
        'OEBPS/book.xhtml',
      ]),
    );
    expect(
      utf8.decode(epub.files.first.content as List<int>),
      'application/epub+zip',
    );
    final epubBook = utf8.decode(
      epub.files.where((file) => file.name == 'OEBPS/book.xhtml').single.content
          as List<int>,
    );
    expect(epubBook, contains('href="#scene-cellar"'));
    expect(
      odt.files.map((file) => file.name),
      containsAll(['mimetype', 'content.xml', 'META-INF/manifest.xml']),
    );
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    expect(
      InternalLinks.resolveForPrint('Continue in [the cellar](scene:cellar).', {
        'cellar': 7,
      }),
      'Continue in the cellar (page 7).',
    );
  });

  test('saved scenes are self-identifying and retain the last good prose', () async {
    final root = await Directory.systemTemp.createTemp('sutoriraita-test-');
    addTearDown(() => root.delete(recursive: true));
    final scene = StoryScene(
      id: 'scene-id',
      title: 'Opening scene',
      content: 'First draft.',
      updatedAt: DateTime(2026),
    );
    final project = StoryProject(
      id: 'project-id',
      title: 'Example',
      author: '',
      language: 'en-AU',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      path: root.path,
      sections: [
        StorySection(id: 'chapter-id', title: 'Chapter One', scenes: [scene]),
      ],
    );
    final store = ProjectStore();
    await store.save(project);

    final manifest = jsonDecode(
      await File('${root.path}${Platform.pathSeparator}sutoriraita.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    expect(manifest['formatVersion'], 1);
    expect(manifest.containsKey('version'), isFalse);
    expect(manifest.containsKey('autosaveDelayMs'), isFalse);
    final sceneFile = File(
      '${root.path}${Platform.pathSeparator}scenes${Platform.pathSeparator}scene-id.md',
    );
    expect(
      await sceneFile.readAsString(),
      startsWith(
        '---\nid: scene-id\ntype: scene\n---\n\n# Opening scene\n\nFirst draft.',
      ),
    );

    scene.content = 'Second draft.';
    await store.save(project);
    final backup = File(
      '${root.path}${Platform.pathSeparator}.recovery${Platform.pathSeparator}scenes${Platform.pathSeparator}scene-id.md.bak',
    );
    expect(await backup.readAsString(), contains('First draft.'));
    expect(
      (await store.open(root.path)).sections.first.scenes.first.content,
      'Second draft.',
    );
  });

  test('new projects are created in the managed Documents library', () async {
    SharedPreferences.setMockInitialValues({});
    final documents = await Directory.systemTemp.createTemp(
      'sutoriraita-documents-',
    );
    addTearDown(() => documents.delete(recursive: true));
    final store = ProjectStore(documentsDirectory: () async => documents);

    final first = await store.create(title: 'My Story', author: 'Writer');
    final second = await store.create(title: 'My Story', author: 'Writer');
    final library = Directory(
      '${documents.path}${Platform.pathSeparator}${ProjectStore.libraryFolderName}',
    );

    expect(first.path, '${library.path}${Platform.pathSeparator}My Story');
    expect(second.path, '${library.path}${Platform.pathSeparator}My Story 2');
    expect(
      await File('${first.path}${Platform.pathSeparator}sutoriraita.json')
          .exists(),
      isTrue,
    );
    await Directory('${library.path}${Platform.pathSeparator}Not a project')
        .create();
    final discovered = await store.discoverProjects();
    expect(
      discovered.map((project) => project.path),
      containsAll([first.path, second.path]),
    );
    expect(discovered, hasLength(2));
  });

  test(
    'startup and experimental detection preferences are app-level',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProjectStore(
        documentsDirectory: () async => Directory.systemTemp,
      );
      await store.saveOpenLastProject(true);
      await store.saveExperimentalEntityDetection(true);
      expect(await store.loadOpenLastProject(), isTrue);
      expect(await store.loadExperimentalEntityDetection(), isTrue);
    },
  );

  test('portable packages contain canonical data only', () async {
    final root = await Directory.systemTemp.createTemp('sutoriraita-pack-');
    addTearDown(() => root.delete(recursive: true));
    final scene = StoryScene(
      id: 'scene',
      title: 'Scene',
      content: 'Canonical prose.',
      updatedAt: DateTime.utc(2026),
    );
    final project = StoryProject(
      id: 'project',
      title: 'Portable',
      author: '',
      language: 'en',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      path: root.path,
      sections: [
        StorySection(id: 'chapter', title: 'One', scenes: [scene]),
      ],
    );
    final store = ProjectStore();
    await store.save(project);
    await Directory('${root.path}${Platform.pathSeparator}assets').create();
    await File(
      '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}map.png',
    ).writeAsBytes([1, 2, 3]);
    await File(
      '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}nested.sutoriraita',
    ).writeAsBytes([4, 5, 6]);
    await File('${root.path}${Platform.pathSeparator}older.sutoriraita')
        .writeAsBytes([7, 8, 9]);
    await File(
      '${root.path}${Platform.pathSeparator}scenes${Platform.pathSeparator}deleted-scene.md',
    ).writeAsString('orphaned prose');
    await File(
      '${root.path}${Platform.pathSeparator}encyclopedia${Platform.pathSeparator}deleted-entry.md',
    ).writeAsString('orphaned lore');
    await Directory('${root.path}${Platform.pathSeparator}.cache').create();
    await File(
      '${root.path}${Platform.pathSeparator}.cache${Platform.pathSeparator}index.bin',
    ).writeAsBytes([10]);

    final package = await store.buildPortablePackage(project);
    final names = ZipDecoder()
        .decodeBytes(package)
        .files
        .map((file) => file.name)
        .toSet();

    expect(
      names,
      containsAll(['sutoriraita.json', 'scenes/scene.md', 'assets/map.png']),
    );
    expect(names.any((name) => name.startsWith('.recovery/')), isFalse);
    expect(names.any((name) => name.startsWith('.cache/')), isFalse);
    expect(names.any((name) => name.endsWith('.sutoriraita')), isFalse);
    expect(names.any((name) => name.contains('deleted-')), isFalse);
  });

  test('entity detection is deterministic and respects experimental types', () {
    final content =
        'Mika met Ren at Moonlight Laundromat. Mika waved to Ren. '
        'The Moonlight Laundromats closed. Sir Squeaks Trolley rattled. '
        "Sir Squeaks Trolley's wheel rattled again.";
    final project = StoryProject(
      id: 'p',
      title: 'Detection',
      author: '',
      language: 'en',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      sections: [
        StorySection(
          id: 'c',
          title: 'One',
          scenes: [
            StoryScene(
              id: 's',
              title: 'Scene',
              content: content,
              updatedAt: DateTime.utc(2026),
            ),
          ],
        ),
      ],
    );
    final detector = EntityDetector();
    final standard = detector.detect(project);
    expect(
      standard.any(
        (item) =>
            item.title == 'Mika' && item.type == EncyclopediaType.character,
      ),
      isTrue,
    );
    expect(
      standard.any(
        (item) =>
            item.title == 'Moonlight Laundromat' &&
            item.type == EncyclopediaType.location,
      ),
      isTrue,
    );
    expect(
      standard.any((item) => item.type == EncyclopediaType.object),
      isFalse,
    );
    final experimental = detector.detect(
      project,
      experimentalObjectsAndEvents: true,
    );
    expect(
      experimental.any(
        (item) =>
            item.title.contains('Trolley') &&
            item.type == EncyclopediaType.object,
      ),
      isTrue,
    );

    project.encyclopedia.add(
      EncyclopediaEntry(
        id: 'mika-entry',
        title: 'Mika',
        type: EncyclopediaType.character,
        content: '',
        updatedAt: DateTime.utc(2026),
      ),
    );
    final withExistingEntry = detector.detect(project);
    expect(
      withExistingEntry.any(
        (item) => item.title.toLowerCase().startsWith('mika'),
      ),
      isFalse,
    );
  });

  test('example story installs as a real editable project', () async {
    SharedPreferences.setMockInitialValues({});
    final documents = await Directory.systemTemp.createTemp(
      'sutoriraita-example-',
    );
    addTearDown(() => documents.delete(recursive: true));
    final store = ProjectStore(documentsDirectory: () async => documents);

    final example = await store.createExample();

    expect(example.title, 'Mochi, Markdown & the Moonlight Laundromat — Copy');
    expect(example.sections, hasLength(6));
    expect(example.sections.expand((section) => section.scenes), hasLength(13));
    expect(example.encyclopedia, hasLength(5));
    expect(example.genres, containsAll(['slice-of-life', 'mystery']));
    expect(example.relations, hasLength(3));
    expect(example.wordCount, greaterThan(500));
    expect(
      await File('${example.path}${Platform.pathSeparator}sutoriraita.json')
          .exists(),
      isTrue,
    );
  });

  test('Novelist v5 stories import hierarchy, order, and emphasis', () async {
    final temp = await Directory.systemTemp.createTemp('sutoriraita_nov_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}${Platform.pathSeparator}story.nov');
    await source.writeAsString(
      jsonEncode({
        'version': 5,
        'title': 'Fallback title',
        'last_update_date': 1787907600000,
        'scenes': [
          {
            'code': 'later',
            'title': 'Later scene',
            'text': jsonEncode({
              'blocks': [
                {'type': 'text', 'text': 'Second'},
              ],
            }),
          },
          {
            'code': 'first',
            'title': 'First scene',
            'text': jsonEncode({
              'blocks': [
                {
                  'type': 'text',
                  'text': 'Very important words',
                  'spans': [
                    {'type': 'italic', 'start': 5, 'end': 14},
                  ],
                },
                {'type': 'text'},
              ],
            }),
          },
        ],
        'books': [
          {
            'title': 'Imported Novel',
            'metadata': jsonEncode({'author': 'A Writer'}),
            'sections': [
              {
                'title': 'Chapter One',
                'ranking': 1,
                'section_scenes': [
                  {'code': 'later', 'ranking': 2},
                  {'code': 'first', 'ranking': 1},
                ],
              },
            ],
          },
        ],
      }),
    );

    final store = ProjectStore(documentsDirectory: () async => temp);
    final project = await store.importNovelistFile(sourcePath: source.path);
    expect(project.title, 'Imported Novel');
    expect(project.author, 'A Writer');
    expect(project.sections.single.title, 'Chapter One');
    expect(project.sections.single.scenes.map((scene) => scene.title), [
      'First scene',
      'Later scene',
    ]);
    expect(
      project.sections.single.scenes.first.content,
      'Very *important* words',
    );
    expect(File('${project.path}/sutoriraita.json').existsSync(), isTrue);
  });

  test(
    'project discovery archives older copies with the same identity',
    () async {
      final temp = await Directory.systemTemp.createTemp('sutoriraita_dupes_');
      addTearDown(() => temp.delete(recursive: true));
      final library = Directory('${temp.path}/Sutōrīraitā Projects');
      for (final copy in [('Old copy', 1), ('New copy', 2)]) {
        final root = Directory('${library.path}/${copy.$1}');
        await root.create(recursive: true);
        final project = StoryProject(
          id: 'same-book',
          title: 'Same Book',
          author: '',
          language: 'en',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 1, copy.$2),
          sections: const [],
        );
        await File('${root.path}/sutoriraita.json')
            .writeAsString(project.prettyJson());
      }
      final projects = await ProjectStore(documentsDirectory: () async => temp)
          .discoverProjects();
      expect(projects, hasLength(1));
      expect(projects.single.path, endsWith('New copy'));
      expect(
        Directory('${library.path}/.archive/Old copy').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'archive and permanent deletion are distinct library operations',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'sutoriraita_archive_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final store = ProjectStore(documentsDirectory: () async => temp);
      final first = await store.create(title: 'Keepable', author: 'Writer');
      final second = await store.create(title: 'Disposable', author: 'Writer');

      await store.archiveProject(first.path!);
      expect(await store.discoverProjects(), hasLength(1));
      final archived = await store.discoverArchivedProjects();
      expect(archived, hasLength(1));
      expect(archived.single.title, 'Keepable');

      await store.permanentlyDeleteProject(second.path!);
      expect(await store.discoverProjects(), isEmpty);
      expect(await store.discoverArchivedProjects(), hasLength(1));

      await store.permanentlyDeleteAllProjects();
      expect(await store.discoverArchivedProjects(), isEmpty);
    },
  );

  test('spellcheck and Prompt Bridge are deterministic and local', () {
    final issues = DeterministicSpellcheck.check('Teh fox fox was wierd.');
    expect(
      issues.map((issue) => issue.suggestion),
      containsAll(['the', 'weird', 'fox']),
    );
    final settings = GemmellSettings(
      tone: 'No tone — preserve chatbot personality',
    );
    final first = settings.prompt(
      tool: GemmellTool.sceneReview,
      project: 'P',
      scene: 'S',
      text: 'Words',
    );
    final second = settings.prompt(
      tool: GemmellTool.sceneReview,
      project: 'P',
      scene: 'S',
      text: 'Words',
    );
    expect(first, second);
    expect(first, contains('Keep your normal conversational personality'));
    expect(first, contains('Tool: Review current scene'));

    final styled =
        GemmellSettings(
          tone: 'Snarky',
          toneIntensity: 5,
          editingStyle: 'Balanced edit',
        ).prompt(
          tool: GemmellTool.sceneReview,
          project: 'P',
          scene: 'S',
          text: 'Words',
        );
    expect(styled, contains('5/5 — Extremely overboard'));
    expect(styled, contains('Editing approach: Balanced edit'));

    final transformationSettings = GemmellSettings(enabled: true);
    expect(transformationSettings.proseTransformationEnabled, isFalse);
    final transformationPrompt = transformationSettings.prompt(
      tool: GemmellTool.expandProse,
      project: 'P',
      scene: 'S',
      text: 'Private surrounding manuscript',
      selection: 'Ren folded the sheet.',
      transformationOptions: 'Preserve meaning, change wording.',
    );
    expect(transformationPrompt, contains('Tool: Expand Prose'));
    expect(transformationPrompt, contains('Scope: selected passage only'));
    expect(transformationPrompt, contains('POV (point of view)'));
    expect(transformationPrompt, contains('intentional grammatical weirdness'));
    expect(transformationPrompt, contains('Return a proposed rewrite'));
    expect(transformationPrompt, contains('Ren folded the sheet.'));
    expect(
      transformationPrompt,
      isNot(contains('Private surrounding manuscript')),
    );
    expect(
      GemmellTool.values
          .where((tool) => tool.proseTransformation)
          .every((tool) => tool.requiresSelection),
      isTrue,
    );

    final selectionPrompt = settings.prompt(
      tool: GemmellTool.factCheck,
      project: 'P',
      scene: 'S',
      text: 'Private surrounding manuscript',
      selection: 'The claim',
    );
    expect(selectionPrompt, contains('Tool: Fact-check claim'));
    expect(selectionPrompt, contains('The claim'));
    expect(selectionPrompt, isNot(contains('Private surrounding manuscript')));
    expect(
      GemmellTool.values.map((tool) => tool.instruction).toSet(),
      hasLength(GemmellTool.values.length),
    );
    expect(
      GemmellTool.values.every((tool) => tool.example.startsWith('Example:')),
      isTrue,
    );
    expect(
      GemmellTool.values.where((tool) => tool.requiresSelection),
      isNotEmpty,
    );
    expect(
      GemmellTool.values.where((tool) => !tool.requiresSelection),
      isNotEmpty,
    );
    final packagePrompt = settings.prompt(
      tool: GemmellTool.storyContinuity,
      project: 'P',
      scene: 'S',
      text: 'This entire manuscript must not be copied into the prompt.',
    );
    expect(
      packagePrompt,
      contains('attached as a .sutoriraita portable package'),
    );
    expect(packagePrompt, contains('If you cannot access attachments'));
    expect(packagePrompt, isNot(contains('entire manuscript must not')));
    expect(
      GemmellTool.values
          .where((tool) => tool.requiresPackage)
          .every((tool) => !tool.requiresSelection),
      isTrue,
    );
    final encyclopediaPrompt = settings.prompt(
      tool: GemmellTool.encyclopediaCanonCheck,
      project: 'P',
      scene: 'Mika',
      subjectKind: 'Character entry',
      text: 'A fox who writes.',
      encyclopedia: '## Ren\nType: Character\nA raccoon.',
    );
    expect(encyclopediaPrompt, contains('Character entry: Mika'));
    expect(encyclopediaPrompt, contains('BEGIN ENCYCLOPEDIA ENTRY'));
    expect(encyclopediaPrompt, contains('BEGIN ENCYCLOPEDIA SNAPSHOT'));
    expect(encyclopediaPrompt, contains('## Ren'));
    expect(
      GemmellTool.values.where((tool) => tool.encyclopediaOnly),
      isNotEmpty,
    );
    final proseFactsPrompt = settings.prompt(
      tool: GemmellTool.structuredFactsFromProse,
      project: 'P',
      scene: 'S',
      text: 'Private surrounding manuscript',
      selection: 'Ren works the night shift.',
    );
    expect(proseFactsPrompt, contains('Ren works the night shift.'));
    expect(proseFactsPrompt, contains('Group facts by entity'));
    expect(GemmellTool.encyclopediaBodyToFacts.encyclopediaOnly, isTrue);
  });

  test('declarative genre packs add subtypes, fields, and relations', () async {
    expect(GenrePacks.builtIns.map((pack) => pack.name), [
      'Mystery',
      'Romance',
      'Horror',
      'Historical',
      'Crime / Thriller',
      'Post-Apocalyptic',
      'Superhero',
      'Adventure',
      'Slice of Life',
      'Dystopian',
      'Science Fiction',
      'Fantasy',
    ]);
    expect(
      GenrePacks.builtIns.every((pack) => pack.relations.isNotEmpty),
      isTrue,
    );
    final temp = await Directory.systemTemp.createTemp('sutoriraita_genre_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}${Platform.pathSeparator}pack.sutorigp');
    await source.writeAsString(
      jsonEncode({
        'format': 'sutoriraita-genre-pack',
        'formatVersion': 1,
        'id': 'laundromat-comedy',
        'name': 'Laundromat Comedy',
        'subtypes': {
          'character': ['Laundry menace'],
        },
        'fields': [
          {
            'key': 'laundryCrime',
            'label': 'Laundry crime',
            'entryType': 'character',
            'subtype': 'Laundry menace',
          },
        ],
        'relations': [
          {
            'id': 'folds-for',
            'label': 'folds laundry for',
            'kind': 'directional',
            'fromTypes': ['character'],
            'toTypes': ['character'],
            'fields': ['success rate'],
          },
        ],
      }),
    );
    final store = ProjectStore(documentsDirectory: () async => temp);
    final pack = await store.importGenrePack(sourcePath: source.path);

    final now = DateTime.utc(2026);
    final entry = EncyclopediaEntry(
      id: 'ren',
      title: 'Ren',
      type: EncyclopediaType.character,
      subtype: 'laundromat-comedy.laundry-menace',
      content: 'Raccoon.',
      updatedAt: now,
    );
    final project = StoryProject(
      id: 'project',
      title: 'Mochi',
      author: '',
      language: 'en',
      createdAt: now,
      updatedAt: now,
      sections: [],
      encyclopedia: [entry],
      customGenrePacks: [pack],
    );

    expect(
      GenrePacks.subtypesFor(project, EncyclopediaType.character),
      contains('laundromat-comedy.laundry-menace'),
    );
    expect(
      GenrePacks.fieldsFor(project, entry).map((field) => field.key),
      contains('laundryCrime'),
    );
    expect(
      GenrePacks.subtypeLabel(project, 'laundromat-comedy.laundry-menace'),
      'Laundry Menace',
    );
    expect(project.toJson()['encyclopediaSchemaVersion'], 2);
    expect(
      project.toJson()['genrePackVersions'],
      containsPair('laundromat-comedy', 1),
    );
    expect(
      GenrePacks.relationsFor(
        project,
        EncyclopediaType.character,
        EncyclopediaType.character,
      ).map((relation) => relation.id),
      contains('folds-for'),
    );
  });

  test('genre fields extend matching core fields', () {
    final now = DateTime.utc(2026);
    final entry = EncyclopediaEntry(
      id: 'ren',
      title: 'Ren',
      type: EncyclopediaType.character,
      content: '',
      updatedAt: now,
    );
    final project = StoryProject(
      id: 'project',
      title: 'Mochi',
      author: '',
      language: 'en',
      createdAt: now,
      updatedAt: now,
      sections: [],
      encyclopedia: [entry],
      genres: ['slice-of-life'],
    );

    final occupation = GenrePacks.fieldsFor(
      project,
      entry,
    ).where((field) => field.label == 'Occupation').toList();
    expect(occupation, hasLength(1));
    expect(occupation.single.key, 'occupation');
  });

  test('project settings save immediately to the project manifest', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('sutoriraita_settings_');
    addTearDown(() => temp.delete(recursive: true));
    final now = DateTime.utc(2026);
    final project = StoryProject(
      id: 'project',
      title: 'Old title',
      author: '',
      language: 'en',
      createdAt: now,
      updatedAt: now,
      sections: [],
      path: temp.path,
    );
    final store = ProjectStore(documentsDirectory: () async => temp);
    await store.save(project);
    final controller = ProjectController(store)..useProject(project);

    await controller.updateProjectSettings(
      title: 'New title',
      author: 'Mika',
      language: 'ja',
      autosaveDelay: 1500,
      genreIds: ['science-fiction', 'fantasy'],
    );

    final manifest = jsonDecode(
      await File('${temp.path}${Platform.pathSeparator}sutoriraita.json')
          .readAsString(),
    ) as Map<String, Object?>;
    expect(manifest['title'], 'New title');
    expect(manifest['author'], 'Mika');
    expect(manifest['language'], 'ja');
    expect(manifest['genres'], ['science-fiction', 'fantasy']);
    expect(controller.saveState, SaveState.saved);
  });

  test('encyclopedia starter generation uses only structured facts', () {
    final now = DateTime.utc(2026);
    final entry = EncyclopediaEntry(
      id: 'ren',
      title: 'Ren',
      type: EncyclopediaType.character,
      subtype: 'mystery.suspect',
      fields: {'occupation': 'Night clerk', 'mystery.motive': 'Protect Mika'},
      content: 'Bad old content that must not leak into the new base.',
      updatedAt: now,
    );
    final project = StoryProject(
      id: 'project',
      title: 'Mochi',
      author: '',
      language: 'en',
      createdAt: now,
      updatedAt: now,
      sections: [],
      encyclopedia: [entry],
      genres: ['mystery'],
    );

    final generated = GenrePacks.generateEntryBase(project, entry);
    expect(generated, contains('Ren is a suspect.'));
    expect(generated, contains('**Occupation:** Night clerk'));
    expect(generated, contains('**Motive:** Protect Mika'));
    expect(generated, isNot(contains('Bad old content')));
  });

  test('genre packs cannot invent top-level types or contain code', () {
    Map<String, Object?> pack(Map<String, Object?> extra) => {
      'format': 'sutoriraita-genre-pack',
      'formatVersion': 1,
      'id': 'bad',
      'name': 'Bad',
      ...extra,
    };

    expect(
      () => GenrePack.fromJson(
        pack({
          'subtypes': {
            'dragon': ['Wyrm'],
          },
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => GenrePack.fromJson(pack({'code': 'launchMissiles()'})),
      throwsFormatException,
    );
  });

  test('bundled Omegaverse genre pack stresses fields and relations', () async {
    final source = File('assets/genre_packs/omegaverse.sutorigp');
    final pack = GenrePack.fromJson(
      (jsonDecode(await source.readAsString()) as Map<String, Object?>),
    );

    expect(pack.name, 'Omegaverse');
    expect(pack.description, contains('Secondary dynamics'));
    expect(pack.fields.length, greaterThanOrEqualTo(15));
    expect(pack.relations.length, greaterThanOrEqualTo(8));
    expect(
      pack.subtypes[EncyclopediaType.character],
      containsAll(['omegaverse.alpha', 'omegaverse.beta', 'omegaverse.omega']),
    );
    expect(
      pack.fields
          .where((field) => field.key == 'omegaverse.nestingPreferences')
          .single
          .subtype,
      'omegaverse.omega',
    );
    expect(
      pack.relations.map((relation) => relation.kind).toSet(),
      containsAll(RelationKind.values),
    );
  });
}

Iterable<TextSpan> _flattenSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _flattenSpans(child);
  }
}
