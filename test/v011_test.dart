import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/chapter_navigator.dart';
import 'package:sutoriraita/document_exporter.dart';
import 'package:sutoriraita/export_wizard.dart';
import 'package:sutoriraita/main.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/project_controller.dart';
import 'package:sutoriraita/project_store.dart';

const cover =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAEElEQVR4nGOokAsAIgYUCgA5nwVlfKDDbAAAAABJRU5ErkJggg==';
StoryProject fixture() {
  final now = DateTime.utc(2026, 9, 5);
  return StoryProject(
    id: 'test',
    title: 'Test',
    author: 'Writer',
    language: 'en',
    createdAt: now,
    updatedAt: now,
    sections: [
      StorySection(
        id: 'a',
        title: 'Alpha',
        scenes: [
          for (var i = 0; i < 3; i++)
            StoryScene(
              id: 's$i',
              title: 'Scene $i',
              content: 'Text',
              updatedAt: now,
            ),
        ],
      ),
      StorySection(id: 'b', title: 'Beta', scenes: []),
    ],
  );
}

class NoSaveStore extends ProjectStore {
  @override
  Future<void> save(StoryProject project) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('chapter and scene moves preserve identity, selection and order', () {
    final c = ProjectController(NoSaveStore())..useProject(fixture());
    addTearDown(c.dispose);
    final p = c.project!, a = p.sections.first, b = p.sections.last;
    final scene = a.scenes.first;
    c.moveChapter(a, 2);
    expect(p.sections, [b, a]);
    expect(a.scenes.map((s) => s.id), ['s0', 's1', 's2']);
    c.moveSceneTo(scene, a, 3);
    expect(a.scenes.map((s) => s.id), ['s1', 's2', 's0']);
    c.moveSceneTo(scene, b, 0);
    expect(b.scenes.single, same(scene));
    expect(c.selectedScene, same(scene));
    c.moveSceneTo(a.scenes.last, b, 0);
    expect(b.scenes.map((s) => s.id), ['s2', 's0']);
    c.moveChapter(a, 0);
    expect(p.sections, [a, b]);
  });

  test(
    'preferences default correctly and survive a fresh controller restore',
    () async {
      final dir = await Directory.systemTemp.createTemp('v011-prefs-');
      addTearDown(() => dir.delete(recursive: true));
      final store = ProjectStore(documentsDirectory: () async => dir);
      final c = ProjectController(store);
      addTearDown(c.dispose);
      await c.restore();
      expect(c.experimentalFeatures, false);
      expect(c.exportWizards, true);
      await c.setExperimentalFeatures(true);
      await c.setExportWizards(false);
      final restored = ProjectController(store);
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.experimentalFeatures, true);
      expect(restored.exportWizards, false);
    },
  );

  test('cover persists locally but native transfers strip it without mutating source', () async {
    final dir = await Directory.systemTemp.createTemp('v011-cover-');
    addTearDown(() => dir.delete(recursive: true));
    final store = ProjectStore(documentsDirectory: () async => dir);
    final p = await store.create(title: 'Cover', author: 'Writer');
    p.coverImage = cover;
    await store.save(p);
    expect((await store.open(p.path)).coverImage, cover);
    final bytes = await store.buildPortablePackage(p);
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = jsonDecode(
      utf8.decode(archive.findFile(ProjectStore.manifestName)!.content),
    );
    expect(manifest.containsKey('coverImage'), false);
    expect((await store.openPackage(bytes: bytes)).coverImage, isNull);
    expect(p.coverImage, cover);
    // Also strip covers from packages made by other versions.
    final incoming = Archive();
    for (final file in archive) {
      if (file.name == ProjectStore.manifestName) {
        final data = utf8.encode(
          jsonEncode({...manifest, 'coverImage': cover}),
        );
        incoming.addFile(ArchiveFile(file.name, data.length, data));
      } else {
        incoming.addFile(file);
      }
    }
    expect(
      (await store.openPackage(
        bytes: Uint8List.fromList(ZipEncoder().encode(incoming)),
      )).coverImage,
      isNull,
    );
  });

  test(
    'supported manuscript formats embed covers; text formats omit them',
    () async {
      final p = fixture()..coverImage = cover;
      for (final format in [ManuscriptFormat.html, ManuscriptFormat.fb2]) {
        final output = utf8.decode(await DocumentExporter.build(p, format));
        expect(output, contains(cover));
      }
      for (final format in [ManuscriptFormat.markdown, ManuscriptFormat.text]) {
        expect(
          utf8.decode(await DocumentExporter.build(p, format)),
          isNot(contains(cover)),
        );
      }
      final epub = ZipDecoder().decodeBytes(
        await DocumentExporter.build(p, ManuscriptFormat.epub),
      );
      expect(epub.first.name, 'mimetype');
      expect(epub.findFile('OEBPS/cover.png')!.content, base64Decode(cover));
      expect(
        utf8.decode(epub.findFile('OEBPS/content.opf')!.content),
        contains('properties="cover-image"'),
      );
      final odt = ZipDecoder().decodeBytes(
        await DocumentExporter.build(p, ManuscriptFormat.odt),
      );
      expect(odt.findFile('Pictures/cover.png')!.content, base64Decode(cover));
      expect(
        utf8.decode(odt.findFile('content.xml')!.content),
        contains('draw:image'),
      );
      final withoutCover = ZipDecoder().decodeBytes(
        await DocumentExporter.build(fixture(), ManuscriptFormat.odt),
      );
      expect(
        utf8.decode(withoutCover.findFile('content.xml')!.content),
        isNot(contains('draw:frame')),
      );
      final pdf = await DocumentExporter.build(p, ManuscriptFormat.pdf);
      expect(latin1.decode(pdf), contains('/Subtype/Image'));
    },
  );

  test('every manuscript wizard format is reachable', () {
    final found = <ManuscriptFormat>{};
    void visit(ExportDecision<ManuscriptFormat> node) {
      if (node.value != null) {
        found.add(node.value!);
      } else {
        visit(node.yes!);
        visit(node.no!);
      }
    }

    visit(manuscriptDecision);
    expect(found, ManuscriptFormat.values.toSet());
  });

  testWidgets('wizard supports back and confirms the chosen format', (
    tester,
  ) async {
    ManuscriptFormat? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showManuscriptExportWizard(context);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF (.pdf)'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.textContaining('EPUB (.epub)'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(result, ManuscriptFormat.epub);
  });

  testWidgets('experimental project creation is opt-in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreateProjectDialog())),
    );
    await tester.tap(find.text('Prose').last);
    await tester.pumpAndSettle();
    expect(find.text('Screenplay'), findsNothing);
    expect(find.text('Interactive fiction (Story / Choice)'), findsNothing);
    await tester.tap(find.text('Prose').last);
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CreateProjectDialog(
            key: ValueKey('enabled'),
            experimentalFeatures: true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Prose').last);
    await tester.pumpAndSettle();
    expect(find.text('Screenplay'), findsOneWidget);
    expect(find.text('Interactive fiction (Story / Choice)'), findsOneWidget);
    expect(find.text('Parser IF prototype'), findsNothing);
  });

  testWidgets('scene grip moves into an empty chapter using its title target', (
    tester,
  ) async {
    final c = ProjectController(NoSaveStore())..useProject(fixture());
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, child) => Column(
              children: [
                for (final section in c.project!.sections)
                  SectionTile(section: section, controller: c),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final grip = find.byType(StoryDragGrip<StoryScene>).first;
    final target = find.text('Beta');
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.project!.sections.last.scenes.single.id, 's0');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets(
    'chapter grip carries scenes and scene slots honor insertion order',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProjectController(NoSaveStore())..useProject(fixture());
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: c,
              builder: (_, child) => ManuscriptSidebar(controller: c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> drag(Finder source, Finder target) async {
        final gesture = await tester.startGesture(tester.getCenter(source));
        await gesture.moveTo(tester.getCenter(target));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag(
        find.byType(StoryDragGrip<StorySection>).first,
        find.byType(StoryDropSlot<StorySection>).last,
      );
      expect(c.project!.sections.map((s) => s.id), ['b', 'a']);
      expect(c.project!.sections.last.scenes.map((s) => s.id), [
        's0',
        's1',
        's2',
      ]);
      final aTile = find.widgetWithText(SectionTile, 'Alpha');
      final slots = find.descendant(
        of: aTile,
        matching: find.byType(StoryDropSlot<StoryScene>),
      );
      await drag(find.byType(StoryDragGrip<StoryScene>).first, slots.last);
      expect(c.project!.sections.last.scenes.map((s) => s.id), [
        's1',
        's2',
        's0',
      ]);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
