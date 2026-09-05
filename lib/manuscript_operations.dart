part of 'project_controller.dart';

class _HistoryFrame {
  _HistoryFrame(
    this.label,
    this.data,
    this.sceneId,
    this.entryId,
    this.selection,
  );
  final String label;
  final Map<String, Object?> data;
  final String? sceneId, entryId;
  final Set<String> selection;
}

class ManuscriptMatch {
  const ManuscriptMatch(this.scene, this.chapter, this.start, this.end);
  final StoryScene scene;
  final StorySection chapter;
  final int start, end;
  String get excerpt => scene.content
      .substring(
        (start - 35).clamp(0, scene.content.length),
        (end + 55).clamp(0, scene.content.length),
      )
      .replaceAll('\n', ' ');
}

extension ManuscriptOperations on ProjectController {
  List<StoryScene> get allScenes =>
      project?.sections.expand((s) => s.scenes).toList() ?? [];
  List<StoryScene> get selectedScenes =>
      allScenes.where((s) => selectedSceneIds.contains(s.id)).toList();
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  String get undoLabel => _undo.isEmpty ? 'Undo' : 'Undo ${_undo.last.label}';
  String get redoLabel => _redo.isEmpty ? 'Redo' : 'Redo ${_redo.last.label}';

  Map<String, Object?> _sceneData(StoryScene scene) => {
    ...scene.toJson(),
    'body': scene.content,
  };
  Map<String, Object?> _chapterData(StorySection section) => {
    ...section.toJson(),
    'scenes': section.scenes.map(_sceneData).toList(),
  };
  Map<String, Object?> _screenplayData(Iterable<StoryScene> scenes) => {
    for (final scene in scenes)
      if (project!.screenplay.containsKey(scene.id))
        scene.id: project!.screenplay[scene.id]!
            .map((e) => e.toJson())
            .toList(),
  };
  StoryScene _readScene(Map<String, Object?> data) =>
      StoryScene.fromJson(data, content: data['body'] as String? ?? '');
  StorySection _readChapter(Map<String, Object?> data) => StorySection(
    id: data['id'] as String,
    title: data['title'] as String,
    scenes: (data['scenes'] as List)
        .map((s) => _readScene((s as Map).cast<String, Object?>()))
        .toList(),
  );

  _HistoryFrame _frame(String label) {
    final data = {
      'sections': project!.sections.map(_chapterData).toList(),
      'encyclopedia': project!.encyclopedia
          .map((e) => {...e.toJson(), 'body': e.content})
          .toList(),
      'relations': project!.relations.map((r) => r.toJson()).toList(),
      'screenplay': _screenplayData(allScenes),
      'trash': project!.trash,
    };
    return _HistoryFrame(
      label,
      (jsonDecode(jsonEncode(data)) as Map).cast<String, Object?>(),
      selectedScene?.id,
      selectedEntry?.id,
      {...selectedSceneIds},
    );
  }

  void _checkpoint(String label, {String? group}) {
    if (project == null) return;
    if (group == null || _editGroup != group || _undo.isEmpty) {
      _undo.add(_frame(label));
      if (_undo.length > 60) _undo.removeAt(0);
    }
    _editGroup = group;
    _redo.clear();
  }

  void _applyFrame(_HistoryFrame frame) {
    requestedSceneRange = null;
    final p = project!, data = frame.data;
    p.sections
      ..clear()
      ..addAll(
        (data['sections'] as List).map(
          (s) => _readChapter((s as Map).cast<String, Object?>()),
        ),
      );
    p.encyclopedia
      ..clear()
      ..addAll(
        (data['encyclopedia'] as List).map((e) {
          final map = (e as Map).cast<String, Object?>();
          return EncyclopediaEntry.fromJson(map)
            ..content = map['body'] as String;
        }),
      );
    p.relations
      ..clear()
      ..addAll(
        (data['relations'] as List).map(
          (r) => EntryRelation.fromJson((r as Map).cast<String, Object?>()),
        ),
      );
    p.trash
      ..clear()
      ..addAll(
        (data['trash'] as List).map((t) => (t as Map).cast<String, Object?>()),
      );
    p.screenplay.clear();
    _restoreScreenplay(data['screenplay']);
    selectedScene =
        allScenes.where((s) => s.id == frame.sceneId).firstOrNull ??
        allScenes.firstOrNull;
    selectedEntry =
        p.encyclopedia.where((e) => e.id == frame.entryId).firstOrNull ??
        p.encyclopedia.firstOrNull;
    selectedSceneIds
      ..clear()
      ..addAll(frame.selection.where((id) => allScenes.any((s) => s.id == id)));
    _editGroup = null;
    editorRevision++;
    changed();
  }

  void undo() {
    if (!canUndo) return;
    final previous = _undo.removeLast();
    _redo.add(_frame(previous.label));
    _applyFrame(previous);
  }

  void redo() {
    if (!canRedo) return;
    final next = _redo.removeLast();
    _undo.add(_frame(next.label));
    _applyFrame(next);
  }

  void selectMention(ManuscriptMatch match) {
    area = WorkspaceArea.manuscript;
    selectedScene = match.scene;
    requestedSceneRange = (start: match.start, end: match.end);
    _selectionChanged();
  }

  void toggleSceneSelection(StoryScene scene, {bool range = false}) {
    final scenes = allScenes;
    final anchor = scenes.indexWhere((s) => s.id == selectionAnchor);
    if (range && anchor >= 0) {
      final end = scenes.indexOf(scene);
      final low = anchor < end ? anchor : end,
          high = anchor > end ? anchor : end;
      selectedSceneIds.addAll(scenes.sublist(low, high + 1).map((s) => s.id));
    } else {
      if (!selectedSceneIds.add(scene.id)) selectedSceneIds.remove(scene.id);
      selectionAnchor = scene.id;
    }
    _selectionChanged();
  }

  void selectChapterScenes(StorySection chapter) {
    selectedSceneIds.addAll(chapter.scenes.map((s) => s.id));
    _selectionChanged();
  }

  void clearSceneSelection() {
    selectedSceneIds.clear();
    _selectionChanged();
  }

  void moveScenes(
    Iterable<StoryScene> input,
    StorySection destination,
    int insertionIndex,
  ) {
    final moving = allScenes.where(input.toSet().contains).toList();
    if (moving.isEmpty || !project!.sections.contains(destination)) return;
    _checkpoint('Move scenes');
    var position = insertionIndex.clamp(0, destination.scenes.length);
    position -= destination.scenes.take(position).where(moving.contains).length;
    for (final section in project!.sections) {
      section.scenes.removeWhere(moving.contains);
    }
    destination.scenes.insertAll(position, moving);
    changed();
  }

  StoryScene splitScene(StoryScene scene, int cursor) {
    final chapter = sectionFor(scene);
    if (chapter == null || cursor <= 0 || cursor >= scene.content.length) {
      throw const FormatException(
        'Place the cursor inside the scene, between the text to keep and split.',
      );
    }
    if (project!.type != ProjectType.prose) {
      throw const FormatException('Split is available for Prose scenes.');
    }
    // Avoid dividing a UTF-16 surrogate pair.
    if (scene.content.codeUnitAt(cursor) >= 0xdc00 &&
        scene.content.codeUnitAt(cursor) <= 0xdfff) {
      cursor--;
    }
    if (cursor == 0) {
      throw const FormatException(
        'Place the cursor after the complete character.',
      );
    }
    _checkpoint('Split scene');
    final newScene = _readScene({
      ..._sceneData(scene),
      'id': _uuid.v4(),
      'title': '${scene.title} (continued)',
      'body': scene.content.substring(cursor),
    });
    scene.content = scene.content.substring(0, cursor);
    scene.updatedAt = DateTime.now();
    chapter.scenes.insert(chapter.scenes.indexOf(scene) + 1, newScene);
    selectedScene = newScene;
    requestedSceneRange = (start: 0, end: 0);
    editorRevision++;
    changed();
    return newScene;
  }

  StoryScene duplicateScene(StoryScene scene) {
    _checkpoint('Duplicate scene');
    final copy = _copyScenes([scene]).single;
    final chapter = sectionFor(scene)!;
    chapter.scenes.insert(chapter.scenes.indexOf(scene) + 1, copy);
    selectedScene = copy;
    changed();
    return copy;
  }

  List<StoryScene> _copyScenes(List<StoryScene> scenes) {
    final ids = {for (final s in scenes) s.id: _uuid.v4()};
    return scenes.map((s) {
      var content = s.content;
      for (final id in ids.entries) {
        content = content.replaceAll(
          '(scene:${id.key})',
          '(scene:${id.value})',
        );
      }
      final copy = _readScene({
        ..._sceneData(s),
        'id': ids[s.id],
        'title': '${s.title} (copy)',
        'body': content,
      });
      if (project!.screenplay[s.id] != null) {
        project!.screenplay[copy.id] = project!.screenplay[s.id]!
            .map(
              (e) =>
                  ScreenplayElement(id: _uuid.v4(), type: e.type, text: e.text),
            )
            .toList();
      }
      return copy;
    }).toList();
  }

  StorySection duplicateChapter(StorySection chapter) {
    _checkpoint('Duplicate chapter');
    final copy = StorySection(
      id: _uuid.v4(),
      title: '${chapter.title} (copy)',
      scenes: _copyScenes(chapter.scenes),
    );
    project!.sections.insert(project!.sections.indexOf(chapter) + 1, copy);
    selectedScene = copy.scenes.firstOrNull;
    changed();
    return copy;
  }

  void duplicateScenes(Iterable<StoryScene> input) {
    final originals = allScenes.where(input.toSet().contains).toList();
    if (originals.isEmpty) return;
    _checkpoint('Duplicate scenes');
    final copies = _copyScenes(originals);
    for (var i = 0; i < originals.length; i++) {
      final chapter = sectionFor(originals[i])!;
      chapter.scenes.insert(
        chapter.scenes.indexOf(originals[i]) + 1,
        copies[i],
      );
    }
    selectedSceneIds
      ..clear()
      ..addAll(copies.map((s) => s.id));
    changed();
  }

  void _trashScene(StoryScene scene) {
    final chapter = sectionFor(scene)!;
    project!.trash.add({
      'id': _uuid.v4(),
      'kind': 'scene',
      'title': scene.title,
      'data': _sceneData(scene),
      'chapterId': chapter.id,
      'chapterTitle': chapter.title,
      'index': chapter.scenes.indexOf(scene),
      'screenplay': _screenplayData([scene]),
      'deletedAt': DateTime.now().toIso8601String(),
    });
    chapter.scenes.remove(scene);
    project!.screenplay.remove(scene.id);
    selectedSceneIds.remove(scene.id);
  }

  void trashScenes(Iterable<StoryScene> input) {
    final scenes = allScenes.where(input.toSet().contains).toList();
    if (scenes.isEmpty) return;
    _checkpoint('Trash scenes');
    // Remove from the end so stored insertion positions remain meaningful.
    for (final scene in scenes.reversed) {
      _trashScene(scene);
    }
    if (scenes.contains(selectedScene)) selectedScene = allScenes.firstOrNull;
    changed();
  }

  void mergeScenes(Iterable<StoryScene> input) {
    final scenes = allScenes.where(input.toSet().contains).toList();
    if (scenes.length < 2) return;
    if (project!.type != ProjectType.prose) {
      throw const FormatException('Merge is available for Prose scenes.');
    }
    _checkpoint('Merge scenes');
    final first = scenes.first;
    first.content = scenes.map((s) => s.content).join('\n\n');
    first.updatedAt = DateTime.now();
    for (final scene in scenes.skip(1).toList().reversed) {
      _trashScene(scene);
    }
    for (final scene in allScenes) {
      for (final removed in scenes.skip(1)) {
        scene.content = scene.content.replaceAll(
          '(scene:${removed.id})',
          '(scene:${first.id})',
        );
      }
    }
    selectedScene = first;
    selectedSceneIds.clear();
    editorRevision++;
    changed();
  }

  void _restoreScreenplay(Object? value) {
    for (final e in (value as Map? ?? {}).entries) {
      project!.screenplay[e.key as String] = (e.value as List)
          .map(
            (v) =>
                ScreenplayElement.fromJson((v as Map).cast<String, Object?>()),
          )
          .toList();
    }
  }

  void restoreTrash(Map<String, Object?> item) {
    if (!project!.trash.contains(item)) return;
    _checkpoint('Restore from trash');
    final data = (item['data'] as Map).cast<String, Object?>();
    if (item['kind'] == 'chapter') {
      final chapter = _readChapter(data);
      final existing = project!.sections
          .where((s) => s.id == chapter.id)
          .firstOrNull;
      // A scene restored first may have recreated its original chapter.
      chapter.scenes.removeWhere(
        (s) => allScenes.any((live) => live.id == s.id),
      );
      if (existing == null) {
        project!.sections.insert(
          (item['index'] as int).clamp(0, project!.sections.length),
          chapter,
        );
        selectedScene = chapter.scenes.firstOrNull;
      } else {
        final positions = (item['restoredPositions'] as Map? ?? {})
            .cast<String, Object?>();
        final restored = [...existing.scenes]
          ..sort(
            (a, b) => ((positions[a.id] as int?) ?? 1000000).compareTo(
              (positions[b.id] as int?) ?? 1000000,
            ),
          );
        final combined = [...chapter.scenes];
        for (final scene in restored) {
          combined.insert(
            ((positions[scene.id] as int?) ?? combined.length).clamp(
              0,
              combined.length,
            ),
            scene,
          );
        }
        existing.scenes
          ..clear()
          ..addAll(combined);
        selectedScene = existing.scenes.firstOrNull;
      }
    } else if (item['kind'] == 'scene') {
      final scene = _readScene(data);
      if (allScenes.any((s) => s.id == scene.id)) {
        throw const FormatException('This scene is already in the manuscript.');
      }
      var chapter = project!.sections
          .where((s) => s.id == item['chapterId'])
          .firstOrNull;
      if (chapter == null) {
        chapter = StorySection(
          id: item['chapterId'] as String,
          title: item['chapterTitle'] as String,
          scenes: [],
        );
        project!.sections.add(chapter);
      }
      for (final parent in project!.trash.where(
        (t) =>
            t['kind'] == 'chapter' && (t['data'] as Map)['id'] == chapter!.id,
      )) {
        final positions = (parent['restoredPositions'] as Map? ?? {})
            .cast<String, Object?>();
        parent['restoredPositions'] = {...positions, scene.id: item['index']};
      }
      chapter.scenes.insert(
        (item['index'] as int).clamp(0, chapter.scenes.length),
        scene,
      );
      selectedScene = scene;
    } else {
      final entry = EncyclopediaEntry.fromJson(data)
        ..content = data['body'] as String;
      project!.encyclopedia.add(entry);
      selectedEntry = entry;
      for (final value in item['relations'] as List? ?? []) {
        final relation = EntryRelation.fromJson(
          (value as Map).cast<String, Object?>(),
        );
        if (project!.encyclopedia.any((e) => e.id == relation.fromEntryId) &&
            project!.encyclopedia.any((e) => e.id == relation.toEntryId) &&
            !project!.relations.any((r) => r.id == relation.id)) {
          project!.relations.add(relation);
        }
      }
    }
    _restoreScreenplay(item['screenplay']);
    project!.trash.remove(item);
    editorRevision++;
    changed();
  }

  void setSceneMetadata(
    StoryScene scene, {
    required String pov,
    required String location,
    required String date,
    required String status,
  }) {
    _checkpoint('Edit scene metadata');
    scene
      ..pov = pov.trim()
      ..location = location.trim()
      ..storyDate = date.trim()
      ..status = status.trim()
      ..updatedAt = DateTime.now();
    changed();
  }

  void setAliases(EncyclopediaEntry entry, Iterable<String> aliases) {
    final cleaned = aliases
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    for (final name in cleaned) {
      if (project!.encyclopedia.any(
        (other) =>
            other.id != entry.id &&
            [
              other.title,
              ...other.aliases,
            ].any((s) => s.toLowerCase() == name.toLowerCase()),
      )) {
        throw FormatException(
          '“$name” is already used by another encyclopedia entry.',
        );
      }
    }
    _checkpoint('Edit aliases');
    entry.aliases
      ..clear()
      ..addAll(cleaned);
    changed();
  }

  RegExp? searchPattern(
    String query, {
    bool matchCase = false,
    bool wholeWord = false,
  }) {
    if (query.isEmpty) return null;
    final escaped = RegExp.escape(query);
    return RegExp(
      wholeWord
          ? r'(?<![\p{L}\p{N}_])' + escaped + r'(?![\p{L}\p{N}_])'
          : escaped,
      caseSensitive: matchCase,
      unicode: true,
    );
  }

  List<ManuscriptMatch> searchManuscript(
    String query, {
    bool matchCase = false,
    bool wholeWord = false,
  }) {
    final pattern = searchPattern(
      query,
      matchCase: matchCase,
      wholeWord: wholeWord,
    );
    if (pattern == null) return [];
    return [
      for (final chapter in project!.sections)
        for (final scene in chapter.scenes)
          for (final match in pattern.allMatches(scene.content))
            ManuscriptMatch(scene, chapter, match.start, match.end),
    ];
  }

  int replaceManuscript(
    String query,
    String replacement, {
    bool matchCase = false,
    bool wholeWord = false,
    String? sceneId,
  }) {
    final pattern = searchPattern(
      query,
      matchCase: matchCase,
      wholeWord: wholeWord,
    );
    if (pattern == null) return 0;
    final hits = searchManuscript(
      query,
      matchCase: matchCase,
      wholeWord: wholeWord,
    ).where((m) => sceneId == null || m.scene.id == sceneId).length;
    if (hits == 0) return 0;
    _checkpoint('Replace manuscript text');
    for (final scene in allScenes.where(
      (s) => sceneId == null || s.id == sceneId,
    )) {
      final updated = scene.content.replaceAllMapped(
        pattern,
        (_) => replacement,
      );
      if (updated != scene.content) {
        scene.content = updated;
        scene.updatedAt = DateTime.now();
      }
    }
    editorRevision++;
    changed();
    return hits;
  }

  List<({EncyclopediaEntry entry, int start, int end})> searchEncyclopedia(
    String query, {
    bool matchCase = false,
    bool wholeWord = false,
  }) {
    final pattern = searchPattern(
      query,
      matchCase: matchCase,
      wholeWord: wholeWord,
    );
    if (pattern == null) return [];
    return [
      for (final entry in project!.encyclopedia)
        for (final match in pattern.allMatches(entry.content))
          (entry: entry, start: match.start, end: match.end),
    ];
  }

  int replaceProjectText(
    String query,
    String replacement, {
    bool matchCase = false,
    bool wholeWord = false,
    bool includeEncyclopedia = true,
  }) {
    final pattern = searchPattern(
      query,
      matchCase: matchCase,
      wholeWord: wholeWord,
    );
    if (pattern == null) return 0;
    final count =
        searchManuscript(
          query,
          matchCase: matchCase,
          wholeWord: wholeWord,
        ).length +
        (includeEncyclopedia
            ? searchEncyclopedia(
                query,
                matchCase: matchCase,
                wholeWord: wholeWord,
              ).length
            : 0);
    if (count == 0) return 0;
    _checkpoint('Replace project text');
    for (final scene in allScenes) {
      final content = scene.content.replaceAllMapped(
        pattern,
        (_) => replacement,
      );
      if (content != scene.content) {
        scene.content = content;
        scene.updatedAt = DateTime.now();
      }
    }
    if (includeEncyclopedia) {
      for (final entry in project!.encyclopedia) {
        final content = entry.content.replaceAllMapped(
          pattern,
          (_) => replacement,
        );
        if (content != entry.content) {
          entry.content = content;
          entry.updatedAt = DateTime.now();
        }
      }
    }
    editorRevision++;
    changed();
    return count;
  }

  List<ManuscriptMatch> backlinks(EncyclopediaEntry entry) {
    final found = <String, ManuscriptMatch>{};
    for (final name in {entry.title, ...entry.aliases}) {
      for (final match in searchManuscript(name, wholeWord: true)) {
        found['${match.scene.id}:${match.start}'] = match;
      }
    }
    return found.values.toList()..sort((a, b) {
      final sceneOrder = allScenes
          .indexOf(a.scene)
          .compareTo(allScenes.indexOf(b.scene));
      return sceneOrder != 0 ? sceneOrder : a.start.compareTo(b.start);
    });
  }
}
