import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'entity_detector.dart';
import 'project_store.dart';

enum SaveState { saved, saving, dirty, error }

enum WorkspaceArea { manuscript, encyclopedia }

class ProjectController extends ChangeNotifier {
  ProjectController(this.store);
  final ProjectStore store;
  final Uuid _uuid = const Uuid();
  StoryProject? project;
  StoryScene? selectedScene;
  SaveState saveState = SaveState.saved;
  Timer? _saveTimer;
  bool _saveInProgress = false;
  Completer<void>? _saveCompletion;
  bool _saveRequested = false;
  bool loading = true;
  int autosaveDelayMs = 700;
  bool openLastProjectOnStartup = false;
  bool experimentalEntityDetection = false;
  WorkspaceArea area = WorkspaceArea.manuscript;
  EncyclopediaEntry? selectedEntry;

  Future<void> restore() async {
    loading = true;
    notifyListeners();
    autosaveDelayMs = await store.loadAutosaveDelay();
    openLastProjectOnStartup = await store.loadOpenLastProject();
    experimentalEntityDetection = await store.loadExperimentalEntityDetection();
    final discovered = await store.discoverProjects();
    project = openLastProjectOnStartup ? await store.openLast() : null;
    if (openLastProjectOnStartup && project == null && discovered.isNotEmpty) {
      project = await store.open(discovered.first.path);
    }
    selectedScene = project?.sections
        .expand((section) => section.scenes)
        .firstOrNull;
    loading = false;
    notifyListeners();
  }

  void useProject(StoryProject value) {
    _saveTimer?.cancel();
    project = value;
    selectedScene = value.sections
        .expand((section) => section.scenes)
        .firstOrNull;
    selectedEntry = value.encyclopedia.firstOrNull;
    area = WorkspaceArea.manuscript;
    saveState = SaveState.saved;
    loading = false;
    notifyListeners();
  }

  Future<void> closeProject() async {
    await saveNow();
    await store.forgetLast();
    project = null;
    selectedScene = null;
    notifyListeners();
  }

  Future<void> showProjectList() async {
    await saveNow();
    project = null;
    selectedScene = null;
    selectedEntry = null;
    notifyListeners();
  }

  Future<void> setOpenLastProject(bool value) async {
    openLastProjectOnStartup = value;
    await store.saveOpenLastProject(value);
    notifyListeners();
  }

  Future<void> setExperimentalEntityDetection(bool value) async {
    experimentalEntityDetection = value;
    await store.saveExperimentalEntityDetection(value);
    notifyListeners();
  }

  void showArea(WorkspaceArea value) {
    area = value;
    notifyListeners();
  }

  void select(StoryScene scene) {
    selectedScene = scene;
    notifyListeners();
  }

  StorySection? sectionFor(StoryScene scene) {
    for (final section in project?.sections ?? const <StorySection>[]) {
      if (section.scenes.contains(scene)) return section;
    }
    return null;
  }

  void updateContent(String content) {
    if (selectedScene == null || selectedScene!.content == content) return;
    selectedScene!
      ..content = content
      ..updatedAt = DateTime.now();
    changed();
  }

  void selectEntry(EncyclopediaEntry entry) {
    selectedEntry = entry;
    area = WorkspaceArea.encyclopedia;
    notifyListeners();
  }

  EncyclopediaEntry addEntry({
    required String title,
    required EncyclopediaType type,
  }) {
    final entry = EncyclopediaEntry(
      id: _uuid.v4(),
      title: title.trim(),
      type: type,
      content: '',
      updatedAt: DateTime.now(),
    );
    project!.encyclopedia.add(entry);
    selectedEntry = entry;
    area = WorkspaceArea.encyclopedia;
    changed();
    return entry;
  }

  void updateEntryContent(String content) {
    if (selectedEntry == null || selectedEntry!.content == content) return;
    selectedEntry!
      ..content = content
      ..updatedAt = DateTime.now();
    changed();
  }

  void updateEntry(
    EncyclopediaEntry entry, {
    String? title,
    EncyclopediaType? type,
  }) {
    if (title != null && title.trim().isNotEmpty) entry.title = title.trim();
    if (type != null) entry.type = type;
    entry.updatedAt = DateTime.now();
    changed();
  }

  void setEntrySubtype(EncyclopediaEntry entry, String? subtype) {
    entry.subtype = subtype?.trim().isEmpty == true ? null : subtype?.trim();
    entry.updatedAt = DateTime.now();
    changed();
  }

  void setEntryField(EncyclopediaEntry entry, String key, String value) {
    if (value.trim().isEmpty) {
      entry.fields.remove(key);
    } else {
      entry.fields[key] = value.trim();
    }
    entry.updatedAt = DateTime.now();
    changed();
  }

  void addCustomEntryField(EncyclopediaEntry entry, String label) {
    final clean = label.trim();
    if (clean.isEmpty) return;
    entry.fields.putIfAbsent('custom:$clean', () => '');
    entry.updatedAt = DateTime.now();
    changed();
  }

  void setGenres(Iterable<String> genreIds) {
    project!.genres
      ..clear()
      ..addAll(genreIds.toSet());
    changed();
  }

  void addGenrePack(GenrePack pack) {
    project!.customGenrePacks.removeWhere((existing) => existing.id == pack.id);
    project!.customGenrePacks.add(pack);
    project!.genrePackVersions[pack.id] = pack.version;
    if (!project!.genres.contains(pack.id)) project!.genres.add(pack.id);
    changed();
  }

  EntryRelation addRelation({
    required EncyclopediaEntry from,
    required EncyclopediaEntry to,
    required RelationTypeDefinition type,
  }) {
    final relation = EntryRelation(
      id: _uuid.v4(),
      fromEntryId: from.id,
      toEntryId: to.id,
      relationTypeId: type.id,
    );
    project!.relations.add(relation);
    changed();
    return relation;
  }

  void setRelationField(EntryRelation relation, String key, String value) {
    if (value.trim().isEmpty) {
      relation.fields.remove(key);
    } else {
      relation.fields[key] = value.trim();
    }
    changed();
  }

  void deleteRelation(EntryRelation relation) {
    project!.relations.remove(relation);
    changed();
  }

  void deleteEntry(EncyclopediaEntry entry) {
    project!.encyclopedia.remove(entry);
    project!.relations.removeWhere(
      (relation) =>
          relation.fromEntryId == entry.id || relation.toEntryId == entry.id,
    );
    if (selectedEntry == entry) {
      selectedEntry = project!.encyclopedia.firstOrNull;
    }
    changed();
  }

  List<EntitySuggestion> get entitySuggestions => EntityDetector().detect(
    project!,
    experimentalObjectsAndEvents: experimentalEntityDetection,
  );

  void changed() {
    saveState = SaveState.dirty;
    if (_saveInProgress) _saveRequested = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(Duration(milliseconds: autosaveDelayMs), saveNow);
  }

  Future<void> setAutosaveDelay(int milliseconds) async {
    autosaveDelayMs = milliseconds;
    await store.saveAutosaveDelay(milliseconds);
    notifyListeners();
  }

  Future<void> updateProjectSettings({
    required String title,
    required String author,
    required String language,
    required int autosaveDelay,
    required Iterable<String> genreIds,
  }) async {
    final value = project!;
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty) value.title = cleanTitle;
    value.author = author.trim();
    value.language = language.trim();
    value.genres
      ..clear()
      ..addAll(genreIds.toSet());
    await setAutosaveDelay(autosaveDelay);
    changed();
    await saveNow();
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final value = project;
    if (value == null || saveState == SaveState.saved) {
      return;
    }
    if (_saveInProgress) {
      _saveRequested = true;
      await _saveCompletion?.future;
      return;
    }
    _saveInProgress = true;
    _saveCompletion = Completer<void>();
    try {
      do {
        _saveRequested = false;
        saveState = SaveState.saving;
        notifyListeners();
        await store.save(value);
      } while (_saveRequested);
      saveState = SaveState.saved;
    } catch (_) {
      saveState = SaveState.error;
    } finally {
      _saveInProgress = false;
      _saveCompletion?.complete();
      _saveCompletion = null;
    }
    notifyListeners();
  }

  StoryScene addScene(StorySection section) {
    final scene = StoryScene(
      id: _uuid.v4(),
      title: 'Untitled scene',
      content: '',
      updatedAt: DateTime.now(),
    );
    section.scenes.add(scene);
    selectedScene = scene;
    changed();
    return scene;
  }

  StorySection addSection() {
    final section = StorySection(
      id: _uuid.v4(),
      title: 'New chapter',
      scenes: [],
    );
    project!.sections.add(section);
    addScene(section);
    return section;
  }

  void renameScene(StoryScene scene, String title) {
    if (title.trim().isNotEmpty) {
      scene.title = title.trim();
      scene.updatedAt = DateTime.now();
      changed();
    }
  }

  void renameSection(StorySection section, String title) {
    if (title.trim().isNotEmpty) {
      section.title = title.trim();
      changed();
    }
  }

  void deleteScene(StoryScene scene) {
    final section = sectionFor(scene);
    if (section == null) return;
    section.scenes.remove(scene);
    if (selectedScene == scene) {
      selectedScene = project!.sections
          .expand((item) => item.scenes)
          .firstOrNull;
    }
    changed();
  }

  void deleteSection(StorySection section) {
    if (project!.sections.length == 1) return;
    final selectedWasInside =
        selectedScene != null && section.scenes.contains(selectedScene);
    project!.sections.remove(section);
    if (selectedWasInside) {
      selectedScene = project!.sections
          .expand((item) => item.scenes)
          .firstOrNull;
    }
    changed();
  }

  void reorderScene(StorySection section, int oldIndex, int newIndex) {
    final scene = section.scenes.removeAt(oldIndex);
    section.scenes.insert(newIndex, scene);
    changed();
  }

  void moveScene(StoryScene scene, StorySection destination) {
    final source = sectionFor(scene);
    if (source == null || source == destination) return;
    source.scenes.remove(scene);
    destination.scenes.add(scene);
    changed();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
