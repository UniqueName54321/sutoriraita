import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'project_documents.dart';
import 'genre_packs.dart';
import 'document_exporter.dart';

class ProjectStore {
  ProjectStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static const manifestName = 'sutoriraita.json';
  static const libraryFolderName = 'Sutōrīraitā Projects';
  static const portableDirectories = <String>{
    'scenes',
    'encyclopedia',
    'notes',
    'research',
    'assets',
  };
  final Uuid _uuid = const Uuid();
  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> projectLibrary() async {
    final documents = await _documentsDirectory();
    return Directory(
      '${documents.path}${Platform.pathSeparator}$libraryFolderName',
    );
  }

  Future<List<ProjectSummary>> discoverProjects() async {
    final library = await projectLibrary();
    if (!await library.exists()) return [];
    final candidates =
        <({Directory directory, StoryProject project, int wordCount})>[];
    await for (final entity in library.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final manifest = File(
        '${entity.path}${Platform.pathSeparator}$manifestName',
      );
      if (!await manifest.exists()) continue;
      try {
        final json =
            jsonDecode(await manifest.readAsString()) as Map<String, Object?>;
        if (json['format'] != 'sutoriraita-project') continue;
        var wordCount = 0;
        final project = StoryProject.fromJson(json, path: entity.path);
        for (final section in project.sections) {
          for (final scene in section.scenes) {
            final file = File(
              '${entity.path}${Platform.pathSeparator}scenes${Platform.pathSeparator}${scene.id}.md',
            );
            if (await file.exists()) {
              wordCount += _decodeScene(await file.readAsString(), scene.id)
                  .content
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((word) => word.isNotEmpty)
                  .length;
            }
          }
        }
        candidates.add((
          directory: entity,
          project: project,
          wordCount: wordCount,
        ));
      } catch (_) {
        // Invalid folders are intentionally ignored by discovery.
      }
    }
    final newestById =
        <
          String,
          ({Directory directory, StoryProject project, int wordCount})
        >{};
    for (final candidate in candidates) {
      final existing = newestById[candidate.project.id];
      if (existing == null ||
          candidate.project.updatedAt.isAfter(existing.project.updatedAt)) {
        newestById[candidate.project.id] = candidate;
      }
    }
    for (final candidate in candidates) {
      if (newestById[candidate.project.id]?.directory.path !=
          candidate.directory.path) {
        await _archiveProject(candidate.directory, library);
      }
    }
    final projects = <ProjectSummary>[];
    for (final candidate in newestById.values) {
      final project = candidate.project;
      projects.add(
        ProjectSummary(
          path: candidate.directory.path,
          title: project.title,
          author: project.author,
          updatedAt: project.updatedAt,
          wordCount: candidate.wordCount,
        ),
      );
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> _archiveProject(Directory source, Directory library) async {
    final archive = Directory(
      '${library.path}${Platform.pathSeparator}.archive',
    );
    await archive.create(recursive: true);
    final leaf = source.path.split(Platform.pathSeparator).last;
    var destination = '${archive.path}${Platform.pathSeparator}$leaf';
    var suffix = 2;
    while (await FileSystemEntity.type(destination) !=
        FileSystemEntityType.notFound) {
      destination = '${archive.path}${Platform.pathSeparator}$leaf $suffix';
      suffix++;
    }
    await source.rename(destination);
  }

  Future<List<ProjectSummary>> discoverArchivedProjects() async {
    final library = await projectLibrary();
    final archive = Directory(
      '${library.path}${Platform.pathSeparator}.archive',
    );
    if (!await archive.exists()) return [];
    final projects = <ProjectSummary>[];
    await for (final entity in archive.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final summary = await _readSummary(entity);
      if (summary != null) projects.add(summary);
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<ProjectSummary?> _readSummary(Directory root) async {
    try {
      final manifest = File(
        '${root.path}${Platform.pathSeparator}$manifestName',
      );
      final json = jsonDecode(await manifest.readAsString());
      if (json is! Map || json['format'] != 'sutoriraita-project') return null;
      final project = StoryProject.fromJson(
        json.cast<String, Object?>(),
        path: root.path,
      );
      var words = 0;
      for (final section in project.sections) {
        for (final scene in section.scenes) {
          final file = File(
            '${root.path}${Platform.pathSeparator}scenes${Platform.pathSeparator}${scene.id}.md',
          );
          if (!await file.exists()) continue;
          words += _decodeScene(await file.readAsString(), scene.id).content
              .trim()
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .length;
        }
      }
      return ProjectSummary(
        path: root.path,
        title: project.title,
        author: project.author,
        updatedAt: project.updatedAt,
        wordCount: words,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> archiveProject(String path) async {
    final library = await projectLibrary();
    _requireManagedPath(path, library, allowArchive: false);
    await _archiveProject(Directory(path), library);
  }

  Future<void> permanentlyDeleteProject(String path) async {
    final library = await projectLibrary();
    _requireManagedPath(path, library, allowArchive: true);
    final target = Directory(path);
    if (await target.exists()) await target.delete(recursive: true);
  }

  Future<void> archiveAllProjects() async {
    final projects = await discoverProjects();
    for (final project in projects) {
      await archiveProject(project.path);
    }
  }

  Future<void> permanentlyDeleteAllProjects() async {
    final active = await discoverProjects();
    final archived = await discoverArchivedProjects();
    for (final project in [...active, ...archived]) {
      await permanentlyDeleteProject(project.path);
    }
  }

  void _requireManagedPath(
    String path,
    Directory library, {
    required bool allowArchive,
  }) {
    final root = library.absolute.path.toLowerCase();
    final target = Directory(path).absolute.path.toLowerCase();
    final archivePrefix = '$root${Platform.pathSeparator}.archive';
    final directParent = Directory(path).parent.absolute.path.toLowerCase();
    final valid =
        directParent == root || (allowArchive && directParent == archivePrefix);
    if (!valid || target == root || target == archivePrefix) {
      throw StateError(
        'Refusing to modify a folder outside the project library.',
      );
    }
  }

  Future<String> backupProject(String path) async {
    final project = await open(path);
    return exportPackage(project);
  }

  Future<StoryProject> create({
    required String title,
    required String author,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final root = await _allocateProjectRoot(title);

    final project = StoryProject(
      id: id,
      title: title.trim(),
      author: author.trim(),
      language: 'en',
      createdAt: now,
      updatedAt: now,
      path: root,
      sections: [
        StorySection(
          id: _uuid.v4(),
          title: 'Chapter One',
          scenes: [
            StoryScene(
              id: _uuid.v4(),
              title: 'Opening scene',
              content: '',
              updatedAt: now,
            ),
          ],
        ),
      ],
    );
    await save(project);
    await remember(project);
    return project;
  }

  Future<StoryProject> createExample() async {
    final template = jsonDecode(
      await rootBundle.loadString('assets/example_project/project.json'),
    ) as Map<String, Object?>;
    final minimumFormatVersion = template['minimumFormatVersion'] as int? ?? 1;
    if (minimumFormatVersion > 1) {
      throw FormatException(
        'The bundled example requires project format version $minimumFormatVersion.',
      );
    }
    final now = DateTime.now();
    final canonicalTitle = template['title'] as String;
    final title = '$canonicalTitle — Copy';
    final project = StoryProject(
      id: _uuid.v4(),
      title: title,
      author: template['author'] as String? ?? '',
      language: template['language'] as String? ?? 'en',
      createdAt: now,
      updatedAt: now,
      path: await _allocateProjectRoot(title),
      sections: (template['sections'] as List<Object?>).map((sectionValue) {
        final section = (sectionValue as Map).cast<String, Object?>();
        return StorySection(
          id: _uuid.v4(),
          title: section['title'] as String,
          scenes: (section['scenes'] as List<Object?>).map((sceneValue) {
            final scene = (sceneValue as Map).cast<String, Object?>();
            return StoryScene(
              id: scene['id'] as String? ?? _uuid.v4(),
              title: scene['title'] as String,
              content: scene['content'] as String,
              updatedAt: now,
            );
          }).toList(),
        );
      }).toList(),
      encyclopedia: (template['encyclopedia'] as List<Object?>? ?? const [])
          .map((entryValue) {
            final entry = (entryValue as Map).cast<String, Object?>();
            return EncyclopediaEntry(
              id: _uuid.v4(),
              title: entry['title'] as String,
              type: EncyclopediaType.fromKey(entry['type'] as String?),
              content: entry['content'] as String? ?? '',
              updatedAt: now,
              subtype: entry['subtype'] as String?,
              fields: (entry['fields'] as Map? ?? const {}).map(
                (key, value) => MapEntry('$key', '$value'),
              ),
            );
          })
          .toList(),
      genres: (template['genres'] as List<Object?>? ?? const []).cast<String>(),
    );
    for (final value in template['relations'] as List<Object?>? ?? const []) {
      final relation = (value as Map).cast<String, Object?>();
      final from = project.encyclopedia
          .where((entry) => entry.title == relation['from'])
          .firstOrNull;
      final to = project.encyclopedia
          .where((entry) => entry.title == relation['to'])
          .firstOrNull;
      if (from == null || to == null) continue;
      project.relations.add(
        EntryRelation(
          id: _uuid.v4(),
          fromEntryId: from.id,
          toEntryId: to.id,
          relationTypeId: relation['type'] as String,
          fields: (relation['fields'] as Map? ?? const {}).map(
            (key, value) => MapEntry('$key', '$value'),
          ),
        ),
      );
    }
    await save(project);
    await remember(project);
    return project;
  }

  Future<String> _allocateProjectRoot(String title) async {
    final library = await projectLibrary();
    await library.create(recursive: true);
    var root = '${library.path}${Platform.pathSeparator}${_safeName(title)}';
    var suffix = 2;
    while (await Directory(root).exists()) {
      root =
          '${library.path}${Platform.pathSeparator}${_safeName(title)} $suffix';
      suffix++;
    }
    return root;
  }

  Future<StoryProject> open([String? chosenPath]) async {
    final root =
        chosenPath ??
        (Platform.isAndroid
            ? await ProjectDocuments.pickTree()
            : await FilePicker.getDirectoryPath(
                dialogTitle: 'Open a Sutōrīraitā project',
              ));
    if (root == null) throw const ProjectCancelled();
    final manifest = await _readProjectFile(root, manifestName);
    if (manifest == null) {
      throw const FormatException(
        'This folder does not contain a Sutōrīraitā project.',
      );
    }
    final json = jsonDecode(utf8.decode(manifest)) as Map<String, Object?>;
    if (json['format'] != 'sutoriraita-project') {
      throw const FormatException(
        'This is not a Sutōrīraitā project manifest.',
      );
    }
    final formatVersion =
        json['formatVersion'] as int? ?? json['version'] as int? ?? 1;
    if (formatVersion > 1) {
      throw FormatException(
        'This project uses unsupported format version $formatVersion.',
      );
    }
    final project = StoryProject.fromJson(json, path: root);
    _validateProjectIds(project);
    GenrePacks.normaliseProjectSchema(project);
    for (final section in project.sections) {
      for (var index = 0; index < section.scenes.length; index++) {
        final scene = section.scenes[index];
        final bytes = await _readProjectFile(root, 'scenes/${scene.id}.md');
        if (bytes != null) {
          final decoded = _decodeScene(utf8.decode(bytes), scene.id);
          scene.content = decoded.content;
          if (decoded.title != null && scene.title.trim().isEmpty) {
            scene.title = decoded.title!;
          }
        }
      }
    }
    for (final entry in project.encyclopedia) {
      final bytes = await _readProjectFile(root, 'encyclopedia/${entry.id}.md');
      if (bytes != null) {
        entry.content = _decodeEncyclopediaEntry(utf8.decode(bytes), entry.id);
      }
    }
    await remember(project);
    return project;
  }

  Future<Uint8List?> _readProjectFile(String root, String path) async {
    if (ProjectDocuments.isTree(root)) return ProjectDocuments.read(root, path);
    final file = File('$root${Platform.pathSeparator}$path');
    return await file.exists() ? file.readAsBytes() : null;
  }

  void _validateProjectIds(StoryProject project) {
    for (final id in [
      ...project.sections.expand((s) => s.scenes).map((s) => s.id),
      ...project.encyclopedia.map((e) => e.id),
    ]) {
      if (id.isEmpty ||
          id == '.' ||
          id == '..' ||
          RegExp(r'[/\\:\x00-\x1f]').hasMatch(id)) {
        throw const FormatException('Unsafe project document ID.');
      }
    }
  }

  Future<void> _saveTree(StoryProject project, String root) async {
    Future<void> write(String path, String content) async {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final previous = await ProjectDocuments.read(root, path);
      if (previous != null && utf8.decode(previous) == content) return;
      if (previous != null) {
        await ProjectDocuments.write(root, '.recovery/$path.bak', previous);
      }
      await ProjectDocuments.write(root, path, bytes);
    }

    for (final scene in project.sections.expand((s) => s.scenes)) {
      await write('scenes/${scene.id}.md', _encodeScene(scene));
    }
    for (final entry in project.encyclopedia) {
      await write(
        'encyclopedia/${entry.id}.md',
        '---\nid: ${entry.id}\ntype: ${entry.type.key}\n---\n\n# ${entry.title}\n\n${entry.content}',
      );
    }
    await write(manifestName, project.prettyJson());
    await write(
      '.recovery/latest.json',
      jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'manifest': manifestName,
      }),
    );
  }

  Future<Uint8List> _buildTreePackage(StoryProject project) async {
    final root = project.path!;
    final archive = Archive();
    final paths = <String>[
      manifestName,
      ...project.sections
          .expand((s) => s.scenes)
          .map((s) => 'scenes/${s.id}.md'),
      ...project.encyclopedia.map((e) => 'encyclopedia/${e.id}.md'),
    ];
    for (final dir in portableDirectories.difference({
      'scenes',
      'encyclopedia',
    })) {
      paths.addAll(
        (await ProjectDocuments.list(root, dir)).where(_isPortableFile),
      );
    }
    for (final path in paths) {
      final bytes = await ProjectDocuments.read(root, path);
      if (bytes != null)
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Opens a snapshot as an independent editable copy; never overwrites its ZIP.
  Future<StoryProject> openPackage({
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    if (bytes == null && sourcePath == null) {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Open Sutōrīraitā project (.sutoriraita)',
        type: Platform.isAndroid || Platform.isIOS
            ? FileType.any
            : FileType.custom,
        allowedExtensions: Platform.isAndroid || Platform.isIOS
            ? null
            : ['sutoriraita'],
      );
      if (picked.isEmpty) throw const ProjectCancelled();
      bytes = await picked.single.readAsBytes();
      sourcePath = picked.single.path;
    }
    bytes ??= await File(sourcePath!).readAsBytes();
    if (bytes.length > 128 * 1024 * 1024) {
      throw const FormatException('Packed project exceeds the 128 MiB limit.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final files = <String, ArchiveFile>{};
    var total = 0;
    for (final file in archive) {
      final path = file.name;
      final parts = path.split('/');
      if (path.startsWith('/') ||
          path.contains('\\') ||
          path.contains(':') ||
          path.contains('\u0000') ||
          parts.any((p) => p == '..' || p == '.') ||
          file.isSymbolicLink) {
        throw const FormatException('Unsafe path in packed project.');
      }
      if (!file.isFile) continue;
      total += file.size;
      if (total > 256 * 1024 * 1024 || files.length >= 10000) {
        throw const FormatException(
          'Packed project exceeds extraction limits.',
        );
      }
      if (files.containsKey(path.toLowerCase())) {
        throw const FormatException('Duplicate path in packed project.');
      }
      files[path.toLowerCase()] = file;
    }
    final manifest = files[manifestName];
    if (manifest == null || manifest.name != manifestName) {
      throw const FormatException('Packed project has no sutoriraita.json.');
    }
    final json =
        jsonDecode(utf8.decode(manifest.content)) as Map<String, Object?>;
    if (json['format'] != 'sutoriraita-project' ||
        (json['formatVersion'] as int? ?? json['version'] as int? ?? 1) > 1) {
      throw const FormatException('Unsupported packed project format.');
    }
    final metadata = StoryProject.fromJson(json);
    _validateProjectIds(metadata);
    final root = Directory(
      await _allocateProjectRoot('${metadata.title} — Copy'),
    );
    try {
      await root.create();
      for (final file in files.values) {
        if (file.name != manifestName &&
            (!portableDirectories.contains(file.name.split('/').first) ||
                !_isPortableFile(file.name))) {
          continue;
        }
        final target = File('${root.path}/${file.name}');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(file.content, flush: true);
      }
      // A new identity prevents library deduplication from archiving the source.
      json['id'] = _uuid.v4();
      await File('${root.path}/$manifestName')
          .writeAsString(jsonEncode(json), flush: true);
      return await open(root.path);
    } catch (_) {
      if (await root.exists()) await root.delete(recursive: true);
      rethrow;
    }
  }

  Future<StoryProject?> openLast() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('lastProjectPath');
    if (path == null) return null;
    try {
      return await open(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> remember(StoryProject project) async {
    if (project.path == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastProjectPath', project.path!);
  }

  Future<void> forgetLast() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastProjectPath');
  }

  Future<int> loadAutosaveDelay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('autosaveDelayMs') ?? 700;
  }

  Future<void> saveAutosaveDelay(int milliseconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autosaveDelayMs', milliseconds);
  }

  Future<bool> loadOpenLastProject() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('openLastProjectOnStartup') ?? false;
  }

  Future<void> saveOpenLastProject(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('openLastProjectOnStartup', value);
  }

  Future<bool> loadExperimentalEntityDetection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('experimentalEntityDetection') ?? false;
  }

  Future<void> saveExperimentalEntityDetection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('experimentalEntityDetection', value);
  }

  Future<void> save(StoryProject project) async {
    final rootPath = project.path;
    if (rootPath == null) throw StateError('The project has no folder.');
    _validateProjectIds(project);
    project.updatedAt = DateTime.now();
    if (ProjectDocuments.isTree(rootPath)) {
      await _saveTree(project, rootPath);
      return;
    }
    final root = Directory(rootPath);
    final scenesDir = Directory('${root.path}${Platform.pathSeparator}scenes');
    final encyclopediaDir = Directory(
      '${root.path}${Platform.pathSeparator}encyclopedia',
    );
    final recoveryDir = Directory(
      '${root.path}${Platform.pathSeparator}.recovery',
    );
    await scenesDir.create(recursive: true);
    await encyclopediaDir.create(recursive: true);
    await recoveryDir.create(recursive: true);

    for (final section in project.sections) {
      for (final scene in section.scenes) {
        final path = '${scenesDir.path}${Platform.pathSeparator}${scene.id}.md';
        await _writeScene(
          target: File(path),
          recovery: File(
            '${recoveryDir.path}${Platform.pathSeparator}scenes${Platform.pathSeparator}${scene.id}.md.bak',
          ),
          scene: scene,
        );
      }
    }
    for (final entry in project.encyclopedia) {
      await _writeEncyclopediaEntry(
        target: File(
          '${encyclopediaDir.path}${Platform.pathSeparator}${entry.id}.md',
        ),
        recovery: File(
          '${recoveryDir.path}${Platform.pathSeparator}encyclopedia${Platform.pathSeparator}${entry.id}.md.bak',
        ),
        entry: entry,
      );
    }
    final manifest = File('${root.path}${Platform.pathSeparator}$manifestName');
    if (await manifest.exists()) {
      await manifest.copy(
        '${recoveryDir.path}${Platform.pathSeparator}$manifestName.bak',
      );
    }
    await _atomicWrite(manifest, project.prettyJson());
    await _atomicWrite(
      File('${recoveryDir.path}${Platform.pathSeparator}latest.json'),
      jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'manifest': manifestName,
      }),
    );
  }

  Future<void> _atomicWrite(File target, String content) async {
    final temporary = File('${target.path}.tmp');
    final previous = File('${target.path}.previous');
    await temporary.parent.create(recursive: true);
    await temporary.writeAsString(content, flush: true);
    if (await previous.exists()) await previous.delete();
    if (await target.exists()) await target.rename(previous.path);
    await temporary.rename(target.path);
    if (await previous.exists()) await previous.delete();
  }

  Future<void> _writeScene({
    required File target,
    required File recovery,
    required StoryScene scene,
  }) async {
    final encoded = _encodeScene(scene);
    if (await target.exists()) {
      final current = await target.readAsString();
      if (current == encoded) return;
      await recovery.parent.create(recursive: true);
      await _atomicWrite(recovery, current);
    }
    await _atomicWrite(target, encoded);
  }

  String _encodeScene(StoryScene scene) =>
      '---\nid: ${scene.id}\ntype: scene\n---\n\n# ${scene.title}\n\n${scene.content}';

  Future<void> _writeEncyclopediaEntry({
    required File target,
    required File recovery,
    required EncyclopediaEntry entry,
  }) async {
    final encoded =
        '---\nid: ${entry.id}\ntype: ${entry.type.key}\n---\n\n# ${entry.title}\n\n${entry.content}';
    if (await target.exists()) {
      final current = await target.readAsString();
      if (current == encoded) return;
      await recovery.parent.create(recursive: true);
      await _atomicWrite(recovery, current);
    }
    await _atomicWrite(target, encoded);
  }

  String _decodeEncyclopediaEntry(String source, String id) {
    final header = RegExp(
      r'^---\r?\nid:\s*([^\r\n]+)\r?\ntype:\s*[^\r\n]+\r?\n---\r?\n(?:\r?\n)?',
    ).firstMatch(source);
    if (header == null || header.group(1)?.trim() != id) return source;
    final body = source.substring(header.end);
    final title = RegExp(r'^#\s+[^\r\n]+\r?\n(?:\r?\n)?').firstMatch(body);
    return title == null ? body : body.substring(title.end);
  }

  ({String content, String? title}) _decodeScene(String source, String id) {
    final header = RegExp(
      r'^---\r?\n(?:(?:[^\r\n]*)\r?\n)*?id:\s*([^\r\n]+)\r?\ntype:\s*scene\r?\n---\r?\n(?:\r?\n)?',
    ).firstMatch(source);
    if (header == null || header.group(1)?.trim() != id) {
      return (content: source, title: null);
    }
    final body = source.substring(header.end);
    final titleMatch = RegExp(r'^#\s+([^\r\n]+)\r?\n(?:\r?\n)?')
        .firstMatch(body);
    return (
      content: titleMatch == null ? body : body.substring(titleMatch.end),
      title: titleMatch?.group(1)?.trim(),
    );
  }

  Future<String> exportMarkdown(StoryProject project) async {
    final content = combinedManuscript(project, markdown: true);
    final output = await FilePicker.saveFile(
      dialogTitle: 'Export Markdown manuscript',
      fileName: '${_safeName(project.title)}.md',
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'text/markdown',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (output == null) throw const ProjectCancelled();
    return output.toString();
  }

  Future<String> exportText(StoryProject project) async {
    final content = combinedManuscript(project, markdown: false);
    final output = await FilePicker.saveFile(
      dialogTitle: 'Export plain-text manuscript',
      fileName: '${_safeName(project.title)}.txt',
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'text/plain',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (output == null) throw const ProjectCancelled();
    return output.toString();
  }

  Future<String> exportPackage(StoryProject project) async {
    await save(project);
    final bytes = await buildPortablePackage(project);
    final output = await FilePicker.saveFile(
      dialogTitle: 'Export portable Sutōrīraitā package',
      fileName: '${_safeName(project.title)}.sutoriraita',
      bytes: bytes,
      mimeType: 'application/zip',
      type: FileType.any,
    );
    if (output == null) throw const ProjectCancelled();
    return output.toString();
  }

  Future<String> exportDocument(
    StoryProject project,
    ManuscriptFormat format,
  ) async {
    await save(project);
    final bytes = await DocumentExporter.build(project, format);
    final output = await FilePicker.saveFile(
      dialogTitle: 'Export ${format.label}',
      fileName: '${_safeName(project.title)}.${format.extension}',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [format.extension],
    );
    if (output == null) throw const ProjectCancelled();
    return output.toString();
  }

  Future<Uint8List> buildPortablePackage(StoryProject project) async {
    if (ProjectDocuments.isTree(project.path!)) {
      return _buildTreePackage(project);
    }
    final archive = Archive();
    final root = Directory(project.path!);
    final files = <File>[];
    final manifest = File('${root.path}${Platform.pathSeparator}$manifestName');
    if (await manifest.exists()) files.add(manifest);
    for (final scene in project.sections.expand((section) => section.scenes)) {
      final file = File(
        '${root.path}${Platform.pathSeparator}scenes${Platform.pathSeparator}${scene.id}.md',
      );
      if (await file.exists()) files.add(file);
    }
    for (final entry in project.encyclopedia) {
      final file = File(
        '${root.path}${Platform.pathSeparator}encyclopedia${Platform.pathSeparator}${entry.id}.md',
      );
      if (await file.exists()) files.add(file);
    }
    for (final directoryName in portableDirectories) {
      if (directoryName == 'scenes' || directoryName == 'encyclopedia') {
        continue;
      }
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}$directoryName',
      );
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && _isPortableFile(entity.path)) files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final relative = file.path
          .substring(root.path.length + 1)
          .replaceAll('\\', '/');
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  bool _isPortableFile(String path) {
    final lower = path.toLowerCase();
    final name = lower.split(RegExp(r'[/\\]')).last;
    if (lower.endsWith('.sutoriraita') ||
        lower.endsWith('.tmp') ||
        lower.endsWith('.previous')) {
      return false;
    }
    return name != 'thumbs.db' && name != 'desktop.ini' && name != '.ds_store';
  }

  Future<StoryProject> importMarkdownFolder() async {
    final source = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder of Markdown files',
    );
    if (source == null) throw const ProjectCancelled();
    final files = await Directory(source)
        .list(recursive: false)
        .where(
          (entry) => entry is File && entry.path.toLowerCase().endsWith('.md'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    if (files.isEmpty) {
      throw const FormatException(
        'No Markdown files were found in that folder.',
      );
    }
    final title = source.split(Platform.pathSeparator).last;
    final project = await create(title: title, author: '');
    final section = project.sections.first;
    section.scenes.clear();
    for (final file in files) {
      final name = file.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.md$', caseSensitive: false),
        '',
      );
      section.scenes.add(
        StoryScene(
          id: _uuid.v4(),
          title: name.replaceAll(RegExp(r'^\d+[\s._-]*'), ''),
          content: await file.readAsString(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    await save(project);
    return project;
  }

  Future<StoryProject> importNovelistFile({String? sourcePath}) async {
    var source = sourcePath;
    if (source == null) {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Choose a Novelist story',
        type: FileType.custom,
        allowedExtensions: const ['nov'],
      );
      source = picked.isEmpty ? null : picked.single.path;
    }
    if (source == null) throw const ProjectCancelled();

    final decoded = jsonDecode(await File(source).readAsString());
    if (decoded is! Map) {
      throw const FormatException('That file is not a valid Novelist story.');
    }
    final data = decoded.cast<String, Object?>();
    final books = (data['books'] as List<Object?>? ?? const []);
    if (books.isEmpty || books.first is! Map) {
      throw const FormatException('The Novelist story contains no book.');
    }
    final book = (books.first as Map).cast<String, Object?>();
    final title = (book['title'] as String? ?? data['title'] as String? ?? '')
        .trim();
    if (title.isEmpty) {
      throw const FormatException('The Novelist story has no title.');
    }

    var author = '';
    final metadataSource = book['metadata'];
    if (metadataSource is String && metadataSource.isNotEmpty) {
      final metadata = jsonDecode(metadataSource);
      if (metadata is Map) author = metadata['author'] as String? ?? '';
    }
    final timestamp = data['last_update_date'];
    final updatedAt = timestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();
    final sceneSources = <String, Map<String, Object?>>{};
    for (final value in data['scenes'] as List<Object?>? ?? const []) {
      if (value is! Map) continue;
      final scene = value.cast<String, Object?>();
      final code = scene['code'] as String?;
      if (code != null) sceneSources[code] = scene;
    }

    final sectionSources =
        (book['sections'] as List<Object?>? ?? const [])
            .whereType<Map>()
            .map((value) => value.cast<String, Object?>())
            .toList()
          ..sort((a, b) => _ranking(a).compareTo(_ranking(b)));
    final sections = <StorySection>[];
    for (final sourceSection in sectionSources) {
      final references =
          (sourceSection['section_scenes'] as List<Object?>? ?? const [])
              .whereType<Map>()
              .map((value) => value.cast<String, Object?>())
              .toList()
            ..sort((a, b) => _ranking(a).compareTo(_ranking(b)));
      final scenes = <StoryScene>[];
      for (final reference in references) {
        final sourceScene = sceneSources[reference['code']];
        if (sourceScene == null) continue;
        scenes.add(
          StoryScene(
            id: _uuid.v4(),
            title: sourceScene['title'] as String? ?? 'Untitled scene',
            content: _novelistTextToMarkdown(sourceScene['text']),
            updatedAt: updatedAt,
          ),
        );
      }
      sections.add(
        StorySection(
          id: _uuid.v4(),
          title: sourceSection['title'] as String? ?? 'Untitled chapter',
          scenes: scenes,
        ),
      );
    }
    if (sections.isEmpty) {
      throw const FormatException('The Novelist story contains no sections.');
    }

    final project = StoryProject(
      id: data['code'] is String && (data['code'] as String).isNotEmpty
          ? 'novelist-${data['code']}'
          : _uuid.v4(),
      title: title,
      author: author.trim(),
      language: 'en',
      createdAt: updatedAt,
      updatedAt: updatedAt,
      path: await _allocateProjectRoot(title),
      sections: sections,
    );
    await save(project);
    await remember(project);
    return project;
  }

  Future<GenrePack> importGenrePack({String? sourcePath}) async {
    var source = sourcePath;
    if (source == null) {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Choose a Sutōrīraitā genre pack',
        type: FileType.custom,
        allowedExtensions: const ['sutorigp'],
      );
      source = picked.isEmpty ? null : picked.single.path;
    }
    if (source == null) throw const ProjectCancelled();
    final decoded = jsonDecode(await File(source).readAsString());
    if (decoded is! Map) {
      throw const FormatException('Genre packs must be declarative JSON.');
    }
    final forbidden = RegExp(
      r'^(code|script|executable|command)$',
      caseSensitive: false,
    );
    if (decoded.keys.any((key) => forbidden.hasMatch('$key'))) {
      throw const FormatException(
        'Genre packs cannot contain executable code.',
      );
    }
    return GenrePack.fromJson(decoded.cast<String, Object?>());
  }

  int _ranking(Map<String, Object?> value) => value['ranking'] as int? ?? 0;

  String _novelistTextToMarkdown(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return '';
    final document = jsonDecode(encoded);
    if (document is! Map) return encoded;
    final lines = <String>[];
    for (final value in document['blocks'] as List<Object?>? ?? const []) {
      if (value is! Map) continue;
      final block = value.cast<String, Object?>();
      var text = block['text'] as String? ?? '';
      final spans =
          (block['spans'] as List<Object?>? ?? const [])
              .whereType<Map>()
              .map((value) => value.cast<String, Object?>())
              .where((span) => span['type'] == 'italic')
              .toList()
            ..sort(
              (a, b) =>
                  (b['start'] as int? ?? 0).compareTo(a['start'] as int? ?? 0),
            );
      for (final span in spans) {
        final start = span['start'] as int? ?? -1;
        final end = span['end'] as int? ?? -1;
        if (start < 0 || end <= start || end > text.length) continue;
        text =
            '${text.substring(0, start)}*${text.substring(start, end)}*'
            '${text.substring(end)}';
      }
      lines.add(text);
    }
    return lines.join('\n\n').trimRight();
  }

  String combinedManuscript(StoryProject project, {required bool markdown}) {
    final buffer = StringBuffer();
    if (markdown) {
      buffer.writeln('# ${project.title}\n');
      if (project.author.isNotEmpty) buffer.writeln('*${project.author}*\n');
    } else {
      buffer.writeln(project.title.toUpperCase());
      if (project.author.isNotEmpty) buffer.writeln('by ${project.author}');
      buffer.writeln();
    }
    for (final section in project.sections) {
      buffer.writeln(
        markdown ? '## ${section.title}\n' : '${section.title.toUpperCase()}\n',
      );
      for (final scene in section.scenes) {
        buffer.writeln(markdown ? '### ${scene.title}\n' : '${scene.title}\n');
        buffer.writeln(scene.content.trim());
        buffer.writeln('\n${markdown ? '---' : '* * *'}\n');
      }
    }
    return buffer.toString().trimRight();
  }

  String _safeName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');
    return safe.isEmpty ? 'Untitled project' : safe;
  }
}

class ProjectCancelled implements Exception {
  const ProjectCancelled();
}
