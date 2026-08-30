import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/project_documents.dart';
import 'package:sutoriraita/project_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory documents;
  late ProjectStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('project-opening-');
    store = ProjectStore(documentsDirectory: () async => documents);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProjectDocuments.channel, null);
    await documents.delete(recursive: true);
  });

  test(
    'packed project preserves content and assets without replacing source',
    () async {
      final original = await store.createExample();
      final asset = File('${original.path}/assets/nested/picture.bin');
      await asset.parent.create(recursive: true);
      await asset.writeAsBytes([1, 2, 3]);
      final bytes = await store.buildPortablePackage(original);
      final copy = await store.openPackage(bytes: bytes);
      expect(copy.id, isNot(original.id));
      expect(copy.path, isNot(original.path));
      expect(
        copy.sections.first.scenes.first.content,
        original.sections.first.scenes.first.content,
      );
      expect(
        await File('${copy.path}/assets/nested/picture.bin').readAsBytes(),
        [1, 2, 3],
      );
      expect((await store.discoverProjects()).length, 2);
      copy.sections.first.scenes.first.content = 'Edited copy';
      await store.save(copy);
      expect(
        (await store.open(copy.path)).sections.first.scenes.first.content,
        'Edited copy',
      );
      expect(
        (await store.open(original.path)).sections.first.scenes.first.content,
        isNot('Edited copy'),
      );
    },
  );

  test('rejects traversal, duplicate paths, unsupported versions and missing manifest', () async {
    final project = await store.create(title: 'Safe', author: '');
    final json = project.toJson();
    Uint8List pack(List<ArchiveFile> files) {
      final archive = Archive();
      for (final file in files) {
        archive.addFile(file);
      }
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    ArchiveFile entry(String name, String content) {
      final bytes = utf8.encode(content);
      return ArchiveFile(name, bytes.length, bytes);
    }

    final manifest = entry('sutoriraita.json', jsonEncode(json));
    for (final files in [
      [manifest, entry('../escape.md', 'bad')],
      [manifest, entry('assets/../../escape.md', 'bad')],
      [manifest, entry('assets/a', 'one'), entry('assets/A', 'two')],
      [
        entry('sutoriraita.json', jsonEncode({...json, 'formatVersion': 999})),
      ],
      [entry('scenes/a.md', 'missing manifest')],
    ]) {
      await expectLater(
        store.openPackage(bytes: pack(files)),
        throwsFormatException,
      );
    }
    expect((await store.discoverProjects()).length, 1);
  });

  test(
    'content tree opens, saves recovery, resumes, and exports through channel',
    () async {
      final original = await store.createExample();
      final files = <String, Uint8List>{};
      final archive = ZipDecoder().decodeBytes(
        await store.buildPortablePackage(original),
      );
      for (final file in archive) {
        files[file.name] = Uint8List.fromList(file.content);
      }
      const tree = 'content://test.provider/tree/opaque%3Aproject';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProjectDocuments.channel, (call) async {
            final args = (call.arguments as Map).cast<String, Object?>();
            expect(args['root'], tree);
            final path = args['path'] as String;
            switch (call.method) {
              case 'read':
                return files[path];
              case 'write':
                files[path] = args['bytes'] as Uint8List;
                return null;
              case 'list':
                return files.keys.where((p) => p.startsWith('$path/')).toList();
            }
            throw StateError('Unexpected ${call.method}');
          });
      final project = await store.open(tree);
      final scene = project.sections.first.scenes.first;
      final old = files['scenes/${scene.id}.md'];
      scene.content = 'Saved through SAF';
      await store.save(project);
      expect(files['.recovery/scenes/${scene.id}.md.bak'], old);
      final resumed = await store.openLast();
      expect(resumed!.path, tree);
      expect(resumed.sections.first.scenes.first.content, 'Saved through SAF');
      final copy = await store.openPackage(
        bytes: await store.buildPortablePackage(project),
      );
      expect(copy.sections.first.scenes.first.content, 'Saved through SAF');
    },
  );

  test(
    'revoked tree access fails without forgetting the persisted location',
    () async {
      SharedPreferences.setMockInitialValues({
        'lastProjectPath': 'content://revoked/tree/id',
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProjectDocuments.channel, (_) async {
            throw PlatformException(
              code: 'permission',
              message: 'Access revoked',
            );
          });
      expect(await store.openLast(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('lastProjectPath'),
        'content://revoked/tree/id',
      );
    },
  );

  test(
    'corrupt ZIP checksums and exact duplicate names are rejected',
    () async {
      final project = await store.create(title: 'Checksums', author: '');
      final archive = Archive();
      final manifest = utf8.encode(project.prettyJson());
      archive.addFile(
        ArchiveFile('sutoriraita.json', manifest.length, manifest),
      );
      archive.addFile(ArchiveFile('assets/a', 1, [1]));
      archive.addFile(ArchiveFile('assets/b', 1, [2]));
      final valid = Uint8List.fromList(ZipEncoder().encode(archive));
      final duplicate = Uint8List.fromList(valid);
      final name = utf8.encode('assets/b');
      for (var i = 0; i <= duplicate.length - name.length; i++) {
        if (String.fromCharCodes(duplicate.sublist(i, i + name.length)) ==
            'assets/b') {
          duplicate[i + name.length - 1] = 'a'.codeUnitAt(0);
        }
      }
      await expectLater(
        store.openPackage(bytes: duplicate),
        throwsFormatException,
      );
      final corrupt = Uint8List.fromList(valid);
      // Central directory CRC lives 16 bytes after its signature.
      for (var i = 0; i < corrupt.length - 20; i++) {
        if (corrupt[i] == 0x50 &&
            corrupt[i + 1] == 0x4b &&
            corrupt[i + 2] == 1 &&
            corrupt[i + 3] == 2) {
          corrupt[i + 16] ^= 0xff;
          break;
        }
      }
      await expectLater(
        store.openPackage(bytes: corrupt),
        throwsFormatException,
      );
      expect((await store.discoverProjects()).length, 1);
    },
  );
}
