import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/main.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/project_controller.dart';
import 'package:sutoriraita/project_store.dart';
import 'package:sutoriraita/gemmell.dart';
import 'package:sutoriraita/gemmell_wizard.dart';
import 'package:sutoriraita/export_wizard.dart';
import 'package:sutoriraita/entity_detector.dart';
import 'package:sutoriraita/manuscript_dialogs.dart';

StoryProject fixture() {
  final now = DateTime.utc(2026, 9, 5);
  return StoryProject(
    id: 'test',
    title: 'Book',
    author: 'Writer',
    language: 'en',
    createdAt: now,
    updatedAt: now,
    sections: [
      StorySection(
        id: 'a',
        title: 'Alpha',
        scenes: [
          StoryScene(
            id: 's0',
            title: 'Opening',
            content: 'Mika walks. Mi sees Mikado. MIKA waits.',
            updatedAt: now,
            pov: 'Mika',
            location: 'Station',
            storyDate: 'Winter 3',
            status: 'Revised',
          ),
          StoryScene(
            id: 's1',
            title: 'Middle',
            content: 'Ren meets Mika.',
            updatedAt: now,
          ),
          StoryScene(
            id: 's2',
            title: 'Ending',
            content: 'Mi leaves. [Return](scene:s0)',
            updatedAt: now,
          ),
        ],
      ),
      StorySection(
        id: 'b',
        title: 'Beta',
        scenes: [
          StoryScene(
            id: 's3',
            title: 'Elsewhere',
            content: 'Someone waves.',
            updatedAt: now,
          ),
        ],
      ),
    ],
    encyclopedia: [
      EncyclopediaEntry(
        id: 'mika',
        title: 'Mika',
        type: EncyclopediaType.character,
        content: 'Mika works nights.',
        updatedAt: now,
        aliases: ['Mi'],
      ),
    ],
  );
}

class NoSaveStore extends ProjectStore {
  @override
  Future<void> save(StoryProject project) async {}
}

ProjectController controller() =>
    ProjectController(NoSaveStore())..useProject(fixture());
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('split preserves exact text, metadata and undo/redo', () {
    final c = controller();
    addTearDown(c.dispose);
    final original = c.allScenes.first.content;
    final after = c.splitScene(c.allScenes.first, 11);
    expect(c.allScenes.take(2).map((s) => s.content).join(), original);
    expect(after.pov, 'Mika');
    expect(after.status, 'Revised');
    final id = after.id;
    c.undo();
    expect(c.allScenes.length, 4);
    expect(c.allScenes.first.content, original);
    c.redo();
    expect(c.allScenes[1].id, id);
    expect(c.selectedScene!.id, id);
  });
  test(
    'typing after a structural edit is undone before the structural edit',
    () {
      final c = controller();
      addTearDown(c.dispose);
      c.duplicateChapter(c.project!.sections.first);
      c.updateContent('A new draft');
      c.updateContent('A new draft with edits');
      c.undo();
      expect(c.selectedScene!.content, contains('Mika walks'));
      expect(c.project!.sections.length, 3);
      c.undo();
      expect(c.project!.sections.length, 2);
      c.redo();
      c.redo();
      expect(c.selectedScene!.content, 'A new draft with edits');
    },
  );
  test(
    'duplicated chapters have independent IDs and internal links target copies',
    () {
      final c = controller();
      addTearDown(c.dispose);
      final chapter = c.duplicateChapter(c.project!.sections.first);
      expect(
        chapter.scenes.last.content,
        contains('(scene:${chapter.scenes.first.id})'),
      );
      expect(chapter.scenes.first.location, 'Station');
      expect(c.allScenes.map((s) => s.id).toSet().length, c.allScenes.length);
      chapter.scenes.first.content = 'Different';
      expect(c.allScenes.first.content, contains('Mika walks'));
    },
  );
  test(
    'range selection moves a whole chunk at the indicated insertion point',
    () {
      final c = controller();
      addTearDown(c.dispose);
      c.toggleSceneSelection(c.allScenes.first);
      c.toggleSceneSelection(c.allScenes[2], range: true);
      expect(c.selectedScenes.length, 3);
      c.moveSceneTo(c.allScenes[1], c.project!.sections.last, 0);
      expect(c.project!.sections.first.scenes, isEmpty);
      expect(c.project!.sections.last.scenes.map((s) => s.id), [
        's0',
        's1',
        's2',
        's3',
      ]);
      c.undo();
      expect(c.project!.sections.first.scenes.length, 3);
      expect(c.selectedScenes.length, 3);
    },
  );
  test(
    'merges preserve first metadata, redirect links, and can undo exactly',
    () {
      final c = controller();
      addTearDown(c.dispose);
      c.allScenes.last.content = '[Middle](scene:s1)';
      c.mergeScenes(c.allScenes.take(2));
      expect(c.allScenes.first.content, contains('\n\nRen meets Mika.'));
      expect(c.allScenes.first.pov, 'Mika');
      expect(c.allScenes.last.content, '[Middle](scene:s0)');
      expect(c.project!.trash.single['title'], 'Middle');
      c.undo();
      expect(c.allScenes.length, 4);
      expect(c.allScenes.last.content, '[Middle](scene:s1)');
      expect(c.project!.trash, isEmpty);
    },
  );
  test('trash chapter, restore and undo restore preserve full text', () {
    final c = controller();
    addTearDown(c.dispose);
    c.deleteSection(c.project!.sections.first);
    expect(c.allScenes.length, 1);
    c.restoreTrash(c.project!.trash.single);
    expect(c.allScenes.first.pov, 'Mika');
    expect(c.allScenes.first.content, contains('Mika walks'));
    c.undo();
    expect(c.allScenes.length, 1);
    expect(c.project!.trash.length, 1);
    c.redo();
    expect(c.allScenes.length, 4);
  });
  test('trash can remove and restore the last chapter', () {
    final c = controller();
    addTearDown(c.dispose);
    c.deleteSection(c.project!.sections.last);
    c.deleteSection(c.project!.sections.first);
    expect(c.allScenes, isEmpty);
    c.restoreTrash(c.project!.trash.last);
    expect(c.allScenes.length, 3);
  });
  test('scene metadata, aliases and trash persist in native saves and portable copies', () async {
    final dir = await Directory.systemTemp.createTemp('v012-persist-');
    addTearDown(() => dir.delete(recursive: true));
    final store = ProjectStore(documentsDirectory: () async => dir);
    final p = await store.create(title: 'Persistent', author: 'Writer');
    p.sections
      ..clear()
      ..addAll(fixture().sections);
    p.encyclopedia.addAll(fixture().encyclopedia);
    final c = ProjectController(store)..useProject(p);
    addTearDown(c.dispose);
    c.trashScenes([c.allScenes.first]);
    await c.saveNow();
    final reopened = await store.open(p.path);
    expect(reopened.encyclopedia.single.aliases, ['Mi']);
    expect(reopened.trash.single['title'], 'Opening');
    c.useProject(
      await store.openPackage(
        bytes: await store.buildPortablePackage(reopened),
      ),
    );
    c.restoreTrash(c.project!.trash.single);
    expect(c.allScenes.first.pov, 'Mika');
    expect(c.allScenes.first.storyDate, 'Winter 3');
    expect(c.allScenes.first.content, contains('Mika walks'));
  });
  test('encyclopedia trash restores entry body, aliases and relationships', () {
    final c = controller();
    addTearDown(c.dispose);
    final entry = c.project!.encyclopedia.single;
    c.deleteEntry(entry);
    expect(c.project!.encyclopedia, isEmpty);
    c.restoreTrash(c.project!.trash.single);
    expect(c.project!.encyclopedia.single.aliases, ['Mi']);
    expect(c.project!.encyclopedia.single.content, 'Mika works nights.');
  });
  test('backlinks include aliases and respect word boundaries and casing', () {
    final c = controller();
    addTearDown(c.dispose);
    final hits = c.backlinks(c.project!.encyclopedia.single);
    expect(hits.length, 5);
    expect(hits.where((m) => m.scene.id == 's0').length, 3);
    c.setAliases(c.project!.encyclopedia.single, ['Mi', 'Night clerk']);
    c.undo();
    expect(c.project!.encyclopedia.single.aliases, ['Mi']);
  });
  test(
    'alias conflicts with other entries are rejected without changing data',
    () {
      final c = controller();
      addTearDown(c.dispose);
      final mika = c.project!.encyclopedia.single;
      c.addEntry(title: 'Ren', type: EncyclopediaType.character);
      expect(() => c.setAliases(mika, ['ren']), throwsFormatException);
      expect(mika.aliases, ['Mi']);
    },
  );
  test('discovery suppresses existing aliases', () {
    final p = fixture();
    p.sections.first.scenes.first.content = 'Nightclerk Nightclerk Nightclerk';
    p.encyclopedia.first.aliases.add('Nightclerk');
    expect(
      EntityDetector().detect(p).any((s) => s.title == 'Nightclerk'),
      false,
    );
  });
  test('project replace is literal, whole-word aware, includes entry text, and undoable', () {
    final c = controller();
    addTearDown(c.dispose);
    expect(c.searchManuscript('Mika', wholeWord: true).length, 3);
    expect(c.replaceProjectText('Mika', r'$New', wholeWord: true), 4);
    expect(
      c.allScenes.first.content,
      contains(r'$New walks. Mi sees Mikado. $New waits.'),
    );
    expect(c.project!.encyclopedia.single.content, r'$New works nights.');
    c.undo();
    expect(c.allScenes.first.content, startsWith('Mika'));
    expect(c.project!.encyclopedia.single.content, 'Mika works nights.');
    expect(c.replaceProjectText('', 'oops'), 0);
    expect(
      c.searchManuscript('Mika', matchCase: true, wholeWord: true).length,
      2,
    );
  });
  test(
    'discovery scope includes only selected source with scene references',
    () {
      final p = fixture(), scene = fixture().sections.first.scenes.first;
      final current = p.sections.first.scenes.first;
      expect(
        discoveryMaterial(p, current, DiscoveryScope.scene),
        contains('[s0]'),
      );
      expect(
        discoveryMaterial(p, current, DiscoveryScope.scene),
        isNot(contains('[s1]')),
      );
      expect(
        discoveryMaterial(p, current, DiscoveryScope.chapter),
        contains('[s2]'),
      );
      expect(
        discoveryMaterial(p, current, DiscoveryScope.chapter),
        isNot(contains('[s3]')),
      );
      expect(
        discoveryMaterial(p, current, DiscoveryScope.manuscript),
        contains('[s3]'),
      );
      expect(scene.pov, 'Mika');
      expect(gemmellEncyclopediaContext(p), contains('Aliases: Mi'));
    },
  );
  test(
    'every available Gemmell tool has a plain-language route and explanation',
    () {
      expect(gemmellQuestions.keys.toSet(), GemmellTool.values.toSet());
      final found = <GemmellTool>{};
      void visit(ExportDecision<GemmellTool> node) {
        if (node.value != null) {
          found.add(node.value!);
        } else {
          visit(node.yes!);
          visit(node.no!);
        }
      }

      visit(gemmellDecision(GemmellTool.values));
      expect(found, GemmellTool.values.toSet());
    },
  );
  test(
    'Gemmell wizard toggle is persisted independently of export toggle',
    () async {
      final settings = await GemmellSettings.load();
      expect(settings.useWizard, true);
      settings.useWizard = false;
      await settings.save();
      expect((await GemmellSettings.load()).useWizard, false);
      expect(await ProjectStore().loadPreference('exportWizards', true), true);
    },
  );
  testWidgets('Gemmell wizard can recommend discovery and go back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGemmellWizard(
              context,
              GemmellTool.values
                  .where((t) => !t.requiresSelection && !t.encyclopediaOnly)
                  .toList(),
              'Gemmell',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Discover encyclopedia entries'),
      findsOneWidget,
    );
    expect(find.text('Use this tool'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Yes'), findsOneWidget);
  });
  testWidgets('scene editor refreshes same-scene text after merge and undo', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, child) => SceneEditor(controller: c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    c.mergeScenes(c.allScenes.take(2));
    await tester.pumpAndSettle();
    final editor = tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!;
    expect(editor.text, contains('Ren meets Mika.'));
    c.undo();
    await tester.pumpAndSettle();
    expect(editor.text, isNot(contains('Ren meets Mika.')));
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('new dialogs fit a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final c = controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showManuscriptSearch(context, c),
              child: const Text('Search'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, 'Mika');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test(
    'restoring a middle scene before its chapter recovers original order',
    () {
      final c = controller();
      addTearDown(c.dispose);
      c.deleteScene(c.allScenes[1]);
      c.deleteSection(c.project!.sections.first);
      c.restoreTrash(c.project!.trash.firstWhere((t) => t['kind'] == 'scene'));
      c.restoreTrash(c.project!.trash.single);
      expect(
        c.project!.sections
            .firstWhere((s) => s.id == 'a')
            .scenes
            .map((s) => s.id),
        ['s0', 's1', 's2'],
      );
    },
  );
  testWidgets('a backlink opens and selects the exact mention', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    final match = c
        .backlinks(c.project!.encyclopedia.single)
        .firstWhere((m) => m.start > 0);
    c.selectMention(match);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SceneEditor(controller: c)),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(text.selection.start, match.start);
    expect(text.selection.end, match.end);
    expect(text.selection.textInside(text.text), 'Mi');
  });
  testWidgets('split at cursor is reachable in the editor menu', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, child) => SceneEditor(controller: c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    final text = tester.widget<TextField>(find.byType(TextField)).controller!;
    text.selection = const TextSelection.collapsed(offset: 11);
    await tester.tap(find.byTooltip('Formatting and scene actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split scene at cursor'));
    await tester.pumpAndSettle();
    expect(c.allScenes.length, 5);
    expect(c.selectedScene!.title, 'Opening (continued)');
    expect(text.selection.start, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  test(
    'relationships survive deleting both entries and restoring either first',
    () {
      for (final reverse in [false, true]) {
        final c = controller();
        addTearDown(c.dispose);
        final mika = c.project!.encyclopedia.single;
        final ren = c.addEntry(title: 'Ren', type: EncyclopediaType.character);
        c.project!.relations.add(
          EntryRelation(
            id: 'r',
            fromEntryId: mika.id,
            toEntryId: ren.id,
            relationTypeId: 'friend',
          ),
        );
        c.deleteEntry(mika);
        c.deleteEntry(ren);
        final items = [...c.project!.trash];
        for (final item in reverse ? items.reversed : items) {
          c.restoreTrash(item);
        }
        expect(c.project!.relations.single.id, 'r');
      }
    },
  );
}
