part of 'project_store.dart';

extension StoryTransfer on ProjectStore {
  String _hammerSourceKey(String path) {
    final value = Directory(path).absolute.uri.normalizePath().toString();
    return Platform.isWindows ? value.toLowerCase() : value;
  }

  /// Discovery is read-only and limited to desktop Documents. Mobile sandboxes
  /// cannot enumerate another app's folders without a user-selected grant.
  Future<List<String>> discoverHammerProjects({bool? supported}) async {
    if (!(supported ??
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS))) {
      return [];
    }
    final prefs = await SharedPreferences.getInstance();
    final handled = prefs.getStringList('hammerHandledSources') ?? [];
    try {
      final documents = await _documentsDirectory();
      final root = Directory('${documents.path}/HammerProjects');
      if (!await root.exists()) return [];
      final found = <String>[];
      await for (final item in root.list(followLinks: false)) {
        if (item is Directory &&
            !handled.contains(_hammerSourceKey(item.path)) &&
            await File('${item.path}/project.toml').exists() &&
            await Directory('${item.path}/scenes').exists()) {
          found.add(item.absolute.path);
        }
      }
      return found..sort();
    } on FileSystemException {
      return []; // Missing access is not permission to bypass the sandbox.
    }
  }

  Future<void> markHammerHandled(Iterable<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final handled = {
      ...?prefs.getStringList('hammerHandledSources'),
      ...paths.map(_hammerSourceKey),
    };
    await prefs.setStringList('hammerHandledSources', handled.toList());
  }

  Future<StoryProject> importHammerFolder({String? sourcePath}) async {
    final root =
        sourcePath ??
        (Platform.isAndroid
            ? await ProjectDocuments.pickTree()
            : await FilePicker.getDirectoryPath(
                dialogTitle: 'Choose a Hammer story folder',
              ));
    if (root == null) throw const ProjectCancelled();
    final files = <String, Uint8List>{};
    var total = 0;
    Future<void> add(String path) async {
      _validateTransferPath(path);
      final bytes = ProjectDocuments.isTree(root)
          ? await ProjectDocuments.read(root, path)
          : await _readPackageStream(File('$root/$path').openRead());
      if (bytes == null) throw FormatException('Missing Hammer file: $path');
      total += bytes.length;
      if (total > 128 * 1024 * 1024 || files.length >= 10000) {
        throw const FormatException(
          'Hammer project exceeds 128 MiB or 10,000 files.',
        );
      }
      files[path] = bytes;
    }

    if (ProjectDocuments.isTree(root)) {
      await add('project.toml');
      final data = await ProjectDocuments.read(root, 'project_data.toml');
      if (data != null) {
        files['project_data.toml'] = data;
        total += data.length;
      }
      for (final directory in [
        'scenes',
        'encyclopedia',
        'notes',
        'timeline',
        'drafts',
      ]) {
        for (final path in await ProjectDocuments.list(root, directory)) {
          await add(path);
        }
      }
    } else {
      if (!await File('$root/project.toml').exists()) {
        throw const FormatException(
          'Choose the story folder containing project.toml, not HammerProjects.',
        );
      }
      await add('project.toml');
      if (await File('$root/project_data.toml').exists()) {
        await add('project_data.toml');
      }
      for (final name in [
        'scenes',
        'encyclopedia',
        'notes',
        'timeline',
        'drafts',
      ]) {
        final directory = Directory('$root/$name');
        if (await FileSystemEntity.type(directory.path, followLinks: false) ==
            FileSystemEntityType.link) {
          throw const FormatException(
            'Linked Hammer folders are not supported.',
          );
        }
        if (!await directory.exists()) continue;
        await for (final item in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (item is Link) {
            throw const FormatException(
              'Linked Hammer files are not supported.',
            );
          }
          if (item is File) {
            final relative = item.path
                .substring(Directory(root).path.length + 1)
                .replaceAll('\\', '/');
            await add(relative);
          }
        }
      }
    }
    final name = ProjectDocuments.isTree(root)
        ? Uri.decodeComponent(Uri.parse(root).pathSegments.last)
              .split('/')
              .last
              .split(':')
              .last
        : Directory(root).uri.pathSegments.where((p) => p.isNotEmpty).last;
    final project = await _importHammerFiles(files, name);
    // Explicit manual import is also consent; do not offer the same source at boot.
    if (!ProjectDocuments.isTree(root)) {
      await markHammerHandled([Directory(root).absolute.path]);
    }
    return project;
  }

  Future<StoryProject> _importHammerFiles(
    Map<String, Uint8List> files,
    String name,
  ) async {
    if (!files.containsKey('project.toml')) {
      throw const FormatException('Missing Hammer project.toml.');
    }
    final decoded = HammerFormat.decode(files, name);
    final project = decoded.project;
    final root = Directory(await _allocateProjectRoot(project.title));
    project.path = root.path;
    try {
      await root.create();
      final source = File('${root.path}/${HammerFormat.sourceFile}');
      await source.parent.create(recursive: true);
      await source.writeAsBytes(decoded.source, flush: true);
      await save(project);
      await remember(project);
      return project;
    } catch (_) {
      if (await root.exists()) await root.delete(recursive: true);
      rethrow;
    }
  }

  Future<Uint8List> buildHammerPackage(StoryProject project) async {
    final source = project.path == null
        ? null
        : await _readProjectFile(project.path!, HammerFormat.sourceFile);
    final files = HammerFormat.encode(project, source: source);
    final archive = Archive();
    final folder = HammerFormat.encodeName(project.title);
    var total = 0;
    for (final entry in files.entries) {
      _validateTransferPath(entry.key);
      total += entry.value.length;
      if (total > 128 * 1024 * 1024) {
        throw const FormatException('Hammer export exceeds 128 MiB.');
      }
      archive.addFile(
        ArchiveFile('$folder/${entry.key}', entry.value.length, entry.value),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<String> exportStory(
    StoryProject project, {
    required bool hammer,
  }) async {
    await save(project);
    final bytes = hammer
        ? await buildHammerPackage(project)
        : NovelistFormat.encode(project);
    final extension = hammer ? 'zip' : 'nov';
    final output = await FilePicker.saveFile(
      dialogTitle: hammer
          ? 'Export Hammer story (unzip into HammerProjects)'
          : 'Export Novelist story',
      fileName:
          '${_safeName(project.title)}${hammer ? '.hammer' : ''}.$extension',
      bytes: bytes,
      type: FileType.any,
      mimeType: hammer ? 'application/zip' : 'application/json',
    );
    if (output == null) throw const ProjectCancelled();
    return output.toString();
  }

  void _validateTransferPath(String path) {
    if (path.isEmpty ||
        path.contains('\\') ||
        RegExp(r'[:\x00-\x1f]').hasMatch(path) ||
        path
            .split('/')
            .any(
              (p) =>
                  p.isEmpty ||
                  p == '.' ||
                  p == '..' ||
                  p.endsWith('.') ||
                  p.endsWith(' ') ||
                  RegExp(
                    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                    caseSensitive: false,
                  ).hasMatch(p),
            )) {
      throw FormatException('Unsafe story path: $path');
    }
  }
}
