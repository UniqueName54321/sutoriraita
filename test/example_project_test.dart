import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/internal_links.dart';
import 'package:sutoriraita/project_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mochi is a known-good reference project and portable round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final documents = await Directory.systemTemp.createTemp('mochi-library-');
    final extracted = await Directory.systemTemp.createTemp('mochi-roundtrip-');
    addTearDown(() async {
      await documents.delete(recursive: true);
      await extracted.delete(recursive: true);
    });
    final store = ProjectStore(documentsDirectory: () async => documents);

    final mochi = await store.createExample();
    final expectedSectionTitles = [
      'Chapter One — A Novel Emergency',
      'Chapter Two — Domestic Markdown',
      'Chapter Three — The Portable Raccoon',
      'Chapter Four — The Index Card Conspiracy',
      'Chapter Five — The Raccoon in the Machine',
      'Chapter Six — Canon Gets Organised',
    ];
    final expectedSceneTitles = [
      'The Blank Page Has Teeth',
      'Ren Names Everything',
      'Bold Decisions, Italic Consequences',
      'The Scene-Switching Incident',
      'The Folder From 2019',
      'One File to Throw at a Critique Group',
      'The Shelf That Finds Its Own Books',
      'Everybody Gets an Index Card',
      'Spelling Without Sorcery',
      'The Manuscript Is Too Large for the Clipboard',
      'Facts With Labels',
      'The Boyfriend Graph',
      'Every Exit Is an Export',
    ];

    expect(mochi.title, 'Mochi, Markdown & the Moonlight Laundromat — Copy');
    expect(mochi.author, 'The Sutōrīraitā House Raccoon');
    expect(mochi.language, 'en');
    expect(
      mochi.sections.map((section) => section.title),
      expectedSectionTitles,
    );
    expect(
      mochi.sections
          .expand((section) => section.scenes)
          .map((scene) => scene.title),
      expectedSceneTitles,
    );
    final scenes = mochi.sections.expand((section) => section.scenes).toList();
    expect(scenes.map((scene) => scene.id).toSet(), hasLength(13));
    expect(mochi.genres, containsAll(['slice-of-life', 'mystery']));
    expect(mochi.encyclopedia.map((entry) => entry.title), [
      'Mika',
      'Ren',
      'Moonlight Laundromat',
      'Sir Squeaks-a-Lot',
      'The Fitted-Sheet Incident',
    ]);
    expect(mochi.encyclopedia.first.fields['role'], isNotEmpty);
    expect(mochi.encyclopedia.first.subtype, 'mystery.suspect');
    expect(
      mochi.encyclopedia.first.fields,
      isNot(contains('slice-of-life.occupation')),
    );
    expect(mochi.relations, hasLength(3));
    expect(mochi.relations.first.fields['workplace'], 'Moonlight Laundromat');
    final manuscript = scenes.map((scene) => scene.content).join('\n');
    for (final fixture in [
      '**Ctrl+B**',
      '*Untitled scene*',
      '## Mika',
      '> Tutorial',
      '- One packet',
      '5 — Extremely overboard',
      'Extract encyclopedia facts from prose',
      'Extract structured facts from entry body',
      'ENABLE PROSE TRANSFORMATION',
      '[Facts With Labels](scene:facts-with-labels)',
      '[Spelling Without Sorcery](scene:spelling-without-sorcery)',
    ]) {
      expect(manuscript, contains(fixture));
    }
    final internalLinks = scenes
        .expand((scene) => InternalLinks.parse(scene.content))
        .toList();
    expect(internalLinks, hasLength(2));
    expect(
      internalLinks.map((link) => link.sceneId),
      containsAll(['facts-with-labels', 'spelling-without-sorcery']),
    );
    expect(
      internalLinks.every(
        (link) => scenes.any((scene) => scene.id == link.sceneId),
      ),
      isTrue,
    );

    final package = await store.buildPortablePackage(mochi);
    final archive = ZipDecoder().decodeBytes(package);
    for (final entry in archive.files.where((file) => file.isFile)) {
      final output = File(
        '${extracted.path}${Platform.pathSeparator}${entry.name.replaceAll('/', Platform.pathSeparator)}',
      );
      await output.parent.create(recursive: true);
      await output.writeAsBytes(entry.content, flush: true);
    }
    final roundTripped = await store.open(extracted.path);

    _expectSameManuscript(mochi, roundTripped);
  });
}

void _expectSameManuscript(StoryProject original, StoryProject restored) {
  expect(restored.id, original.id);
  expect(restored.title, original.title);
  expect(restored.author, original.author);
  expect(restored.language, original.language);
  expect(restored.genres, original.genres);
  expect(
    restored.relations.map((relation) => relation.toJson()),
    original.relations.map((relation) => relation.toJson()),
  );
  expect(
    restored.encyclopedia.map((entry) => entry.id),
    original.encyclopedia.map((entry) => entry.id),
  );
  expect(
    restored.encyclopedia.map((entry) => entry.content),
    original.encyclopedia.map((entry) => entry.content),
  );
  expect(
    restored.encyclopedia.map((entry) => entry.fields),
    original.encyclopedia.map((entry) => entry.fields),
  );
  expect(
    restored.sections.map((section) => section.id),
    original.sections.map((section) => section.id),
  );
  final originalScenes = original.sections
      .expand((section) => section.scenes)
      .toList();
  final restoredScenes = restored.sections
      .expand((section) => section.scenes)
      .toList();
  expect(
    restoredScenes.map((scene) => scene.id),
    originalScenes.map((scene) => scene.id),
  );
  expect(
    restoredScenes.map((scene) => scene.title),
    originalScenes.map((scene) => scene.title),
  );
  expect(
    restoredScenes.map((scene) => scene.content),
    originalScenes.map((scene) => scene.content),
  );
}
