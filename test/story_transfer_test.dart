import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/hammer_format.dart';
import 'package:sutoriraita/main.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/novelist_format.dart';
import 'package:sutoriraita/project_documents.dart';
import 'package:sutoriraita/project_store.dart';

Map<String, Uint8List> fixture() => {
  for (final e in <String, String>{
    'project.toml': '[info]\ncreated = "2023-01-30T06:03:18Z"\nlastAccessed = null\ndataVersion = 2\nserverProjectId = null\n',
    'project_data.toml': '[data]\nauthorName = "Writer"\nlanguage = "en-US"\n[data.wordCountGoal]\ncount = 1000\ncadence = "WEEK"\n',
    'scenes/00~Title~1.md': 'Title page\n',
    'scenes/02~Later~4/0~End~5.md': 'End\n',
    'scenes/01~Chapter꞉ One~2/0~First？~3.md': 'A *quiet* **story**.\n',
    'encyclopedia/person/person-6-Alice.toml': '[entry]\nid = 6\nname = "Alice"\ntype = "PERSON"\ntext = "A null value is not missing prose."\ntags = ["hero"]\n',
    'notes/note-99.toml': '[note]\nid = 99\ncontent = "Keep this note"\n',
    'timeline/timeline.toml': '[[events]]\nid = 100\norder = 0\ncontent = """A line\nnull is prose"""\n',
  }.entries)
    e.key: Uint8List.fromList(utf8.encode(e.value)),
  'encyclopedia/person/person-6-image.jpg': Uint8List.fromList([1, 2, 3, 4]),
};

Future<void> writeFixture(Directory root, Map<String, Uint8List> files) async {
  for (final entry in files.entries) {
    final file = File('${root.path}/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(entry.value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final accept in [false, true]) {
    testWidgets(
      'Startup Hammer prompt ${accept ? 'imports only after confirmation' : 'allows declining without importing'}',
      (tester) async {
        late Directory temp;
        await tester.runAsync(() async {
          temp = await Directory.systemTemp.createTemp('hammer_prompt_');
          await writeFixture(
            Directory('${temp.path}/HammerProjects/Story'),
            fixture(),
          );
        });
        addTearDown(() => temp.delete(recursive: true));
        final store = ProjectStore(documentsDirectory: () async => temp);
        await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
        Future<void> waitFor(String text) async {
          // Real ZIP/file I/O can take several seconds on a cold Windows or CI
          // filesystem; keep pumping the UI instead of treating 2 seconds as a
          // product failure.
          for (var i = 0; i < 1500 && find.text(text).evaluate().isEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          expect(find.text(text), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
        }

        await waitFor('Import your Hammer stories?');
        await tester.runAsync(
          () async =>
              expect(await (await store.projectLibrary()).exists(), isFalse),
        );
        await tester.tap(
          find.text(accept ? 'Import copies' : 'Skip these stories'),
        );
        await tester.pump();
        if (accept) {
          await waitFor('Imported 1 Hammer stories');
          await tester.tap(find.text('Done'));
        } else {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          expect(await store.discoverHammerProjects(supported: true), isEmpty);
          expect(await (await store.projectLibrary()).exists(), accept);
        });
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('Hammer TOML null adaptation leaves strings, comments and multiline prose unchanged', () {
    final parsed = HammerFormat.parseToml(
      '[info]\nx = null # null\ny = "null"\nz = """line\nnull"""\n',
    );
    expect(parsed['info'], {'x': null, 'y': 'null', 'z': 'line\nnull'});
  });

  test('Hammer keeps ordered root scenes, Unicode titles and unchanged ancillary bytes', () {
    final input = fixture();
    final result = HammerFormat.decode(input, 'Test');
    expect(result.project.author, 'Writer');
    expect(result.project.sections.map((s) => s.title), [
      'Ungrouped scenes',
      'Chapter: One',
      'Later',
    ]);
    expect(result.project.sections[1].scenes.single.title, 'First?');
    result.project.sections[1].scenes.single.content = 'Edited scene';
    final output = HammerFormat.encode(result.project, source: result.source);
    expect(
      utf8.decode(output['scenes/01~Chapter꞉ One~2/0~First？~3.md']!),
      'Edited scene',
    );
    for (final path in [
      'notes/note-99.toml',
      'timeline/timeline.toml',
      'encyclopedia/person/person-6-image.jpg',
    ]) {
      expect(output[path], input[path]);
    }
    expect(
      HammerFormat.parseToml(
        utf8.decode(output['project_data.toml']!),
      )['data']['wordCountGoal']['count'],
      1000,
    );
    expect(
      HammerFormat.parseToml(
        utf8.decode(output['project.toml']!),
      )['info']['serverProjectId'],
      isNull,
    );
  });

  test('Hammer structural edits preserve manuscript order and allocate nonconflicting IDs', () {
    final result = HammerFormat.decode(fixture(), 'Test');
    result.project.sections.first.scenes.add(
      StoryScene(
        id: 'new',
        title: 'Added',
        content: 'New',
        updatedAt: DateTime.now(),
      ),
    );
    result.project.sections.removeLast();
    final output = HammerFormat.encode(result.project, source: result.source);
    expect(output.keys.any((p) => p.endsWith('~5.md')), isFalse);
    final added = output.keys.singleWhere((p) => p.contains('~Added~'));
    expect(
      int.parse(RegExp(r'~(\d+)\.md$').firstMatch(added)![1]!),
      greaterThan(100),
    );
    final imported = HammerFormat.decode(output, 'Test').project;
    expect(imported.sections.expand((s) => s.scenes).map((s) => s.content), [
      'Title page\n',
      'New',
      'A *quiet* **story**.\n',
    ]);
  });

  test('Hammer rejects unknown versions and duplicate numeric IDs', () {
    final bad = fixture();
    bad['project.toml'] = Uint8List.fromList(
      utf8.encode('[info]\ndataVersion = 99'),
    );
    expect(() => HammerFormat.decode(bad, 'Bad'), throwsFormatException);
    final duplicate = fixture()..['scenes/03~Duplicate~3.md'] = Uint8List(0);
    expect(() => HammerFormat.decode(duplicate, 'Bad'), throwsFormatException);
  });

  test('Folder import makes an independent copy and portable package retains Hammer source', () async {
    final temp = await Directory.systemTemp.createTemp('hammer_test_');
    addTearDown(() => temp.delete(recursive: true));
    final source = Directory('${temp.path}/HammerProjects/Story');
    final input = fixture();
    await writeFixture(source, input);
    final store = ProjectStore(documentsDirectory: () async => temp);
    expect(
      (await store.discoverHammerProjects(supported: true))
          .map((p) => p.replaceAll('\\', '/')),
      [source.absolute.path.replaceAll('\\', '/')],
    );
    final project = await store.importHammerFolder(sourcePath: source.path);
    expect(project.path, isNot(source.path));
    expect(await store.discoverHammerProjects(supported: true), isEmpty);
    project.sections[1].scenes.single.content = 'New text';
    await store.save(project);
    expect(
      await File('${source.path}/scenes/01~Chapter꞉ One~2/0~First？~3.md')
          .readAsBytes(),
      input['scenes/01~Chapter꞉ One~2/0~First？~3.md'],
    );
    final copied = await store.openPackage(
      bytes: await store.buildPortablePackage(project),
    );
    final archive = ZipDecoder().decodeBytes(
      await store.buildHammerPackage(copied),
    );
    expect(
      archive.findFile('Story/notes/note-99.toml')!.content,
      input['notes/note-99.toml'],
    );
    expect(
      utf8.decode(
        archive
            .findFile('Story/scenes/01~Chapter꞉ One~2/0~First？~3.md')!
            .content,
      ),
      'New text',
    );
  });

  test('Skipping startup import writes only a preference; manual import remains available', () async {
    final temp = await Directory.systemTemp.createTemp('hammer_consent_');
    addTearDown(() => temp.delete(recursive: true));
    final source = Directory('${temp.path}/HammerProjects/Story');
    await writeFixture(source, fixture());
    final store = ProjectStore(documentsDirectory: () async => temp);
    await store.markHammerHandled(
      await store.discoverHammerProjects(supported: true),
    );
    expect(await store.discoverHammerProjects(supported: true), isEmpty);
    expect(await (await store.projectLibrary()).exists(), isFalse);
    expect(
      (await store.importHammerFolder(sourcePath: source.path)).wordCount,
      greaterThan(0),
    );
  });

  test(
    'Android Hammer import reads a content tree without File URI conversion',
    () async {
      final temp = await Directory.systemTemp.createTemp('hammer_saf_');
      addTearDown(() => temp.delete(recursive: true));
      final input = fixture();
      const root = 'content://provider/tree/primary%3AHammerProjects%2FStory';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(ProjectDocuments.channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        expect(args['root'], root);
        if (call.method == 'read') return input[args['path']];
        if (call.method == 'list') {
          return input.keys
              .where((p) => p.startsWith('${args['path']}/'))
              .toList();
        }
        throw PlatformException(code: 'unexpected');
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(ProjectDocuments.channel, null),
      );
      final project = await ProjectStore(documentsDirectory: () async => temp)
          .importHammerFolder(sourcePath: root);
      expect(project.title, 'Story');
      expect(project.sections.length, 3);
    },
  );

  test(
    'Novelist backup exports ordered scenes, emphasis, author and encyclopedia',
    () async {
      final temp = await Directory.systemTemp.createTemp('nov_export_');
      addTearDown(() => temp.delete(recursive: true));
      final project = HammerFormat.decode(fixture(), 'Novel').project;
      final bytes = NovelistFormat.encode(project);
      final data = jsonDecode(utf8.decode(bytes));
      expect(data['version'], 4);
      expect(data['revisions'].single['sections'].length, 3);
      final source = File('${temp.path}/test.nov');
      await source.writeAsBytes(bytes);
      final store = ProjectStore(documentsDirectory: () async => temp);
      final imported = await store.importNovelistFile(sourcePath: source.path);
      expect(imported.author, 'Writer');
      expect(
        imported.sections[1].scenes.single.content,
        'A *quiet* **story**.',
      );
      expect(imported.encyclopedia.single.title, 'Alice');
      final again = await store.importNovelistFile(sourcePath: source.path);
      expect(imported.id, isNot(again.id));
    },
  );

  test(
    'Hammer ZIP import uses safe extraction and supports empty stories',
    () async {
      final temp = await Directory.systemTemp.createTemp('hammer_zip_');
      addTearDown(() => temp.delete(recursive: true));
      final store = ProjectStore(documentsDirectory: () async => temp);
      final project = HammerFormat.decode(fixture(), 'A story').project;
      final imported = await store.importHammerPackage(
        bytes: await store.buildHammerPackage(project),
      );
      expect(imported.title, 'A story');
      expect(imported.wordCount, project.wordCount);
      final malicious = Archive()
        ..addFile(
          ArchiveFile.string('../project.toml', '[info]\ndataVersion = 2'),
        );
      await expectLater(
        store.importHammerPackage(
          bytes: Uint8List.fromList(ZipEncoder().encode(malicious)),
        ),
        throwsFormatException,
      );
      for (final section in project.sections) {
        section.scenes.clear();
      }
      final empty = await store.buildHammerPackage(project);
      expect(
        ZipDecoder().decodeBytes(empty).findFile('A story/scenes/'),
        isNotNull,
      );
      expect((await store.importHammerPackage(bytes: empty)).wordCount, 0);
    },
  );

  final examples = Platform.environment['SUTORIRAITA_HAMMER_EXAMPLES'];
  test(
    'Provided Hammer examples import and export without changing manuscript or ancillary files',
    () async {
      final temp = await Directory.systemTemp.createTemp('hammer_examples_');
      addTearDown(() => temp.delete(recursive: true));
      final store = ProjectStore(documentsDirectory: () async => temp);
      for (final source in Directory(
        examples!,
      ).listSync().whereType<Directory>()) {
        if (!File('${source.path}/project.toml').existsSync()) continue;
        final project = await store.importHammerFolder(sourcePath: source.path);
        final archive = ZipDecoder().decodeBytes(
          await store.buildHammerPackage(project),
        );
        final output = <String, Uint8List>{
          for (final file in archive.files.where((f) => f.isFile))
            file.name.substring(file.name.indexOf('/') + 1): Uint8List.fromList(
              file.content,
            ),
        };
        final roundtrip = HammerFormat.decode(output, project.title).project;
        expect(
          roundtrip.sections
              .expand((s) => s.scenes)
              .map((s) => s.content)
              .toList(),
          project.sections
              .expand((s) => s.scenes)
              .map((s) => s.content)
              .toList(),
        );
        for (final file in source.listSync(recursive: true).whereType<File>()) {
          final path = file.path
              .substring(source.path.length + 1)
              .replaceAll('\\', '/');
          if (path.startsWith('notes/') ||
              path.startsWith('timeline/') ||
              path.endsWith('.jpg')) {
            expect(output[path], file.readAsBytesSync(), reason: path);
          }
        }
      }
    },
    skip: examples == null
        ? 'Set SUTORIRAITA_HAMMER_EXAMPLES for local read-only example verification.'
        : false,
  );
}
