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
  IfNode? selectedIfNode;

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
    selectedIfNode = value.interactiveFiction.nodes.firstWhere(
      (node) => node.id == value.interactiveFiction.startNodeId,
      orElse: () =>
          value.interactiveFiction.nodes.firstOrNull ??
          IfNode(id: '', title: ''),
    );
    if (selectedIfNode?.id.isEmpty == true) selectedIfNode = null;
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
    if (project!.type == ProjectType.screenplay) {
      project!.screenplay[scene.id] = [
        ScreenplayElement(
          id: _uuid.v4(),
          type: ScreenplayElementType.sceneHeading,
          text: 'INT. LOCATION - DAY',
        ),
      ];
    }
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
    project!.screenplay.remove(scene.id);
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

  void updateScreenplayElement(
    ScreenplayElement element, {
    String? text,
    ScreenplayElementType? type,
  }) {
    if (text != null) element.text = text;
    if (type != null) element.type = type;
    changed();
  }

  ScreenplayElement addScreenplayElement(
    StoryScene scene,
    int index,
    ScreenplayElementType type,
  ) {
    final element = ScreenplayElement(id: _uuid.v4(), type: type);
    final elements = project!.screenplay.putIfAbsent(scene.id, () => []);
    elements.insert(index.clamp(0, elements.length), element);
    changed();
    return element;
  }

  void deleteScreenplayElement(StoryScene scene, ScreenplayElement element) {
    final elements = project!.screenplay[scene.id];
    if (elements == null || elements.length <= 1) return;
    elements.remove(element);
    changed();
  }

  void selectIfNode(IfNode node) {
    selectedIfNode = node;
    notifyListeners();
  }

  IfNode addIfNode() {
    final index = project!.interactiveFiction.nodes.length;
    final node = IfNode(
      id: _uuid.v4(),
      title: 'Passage ${index + 1}',
      x: (index % 4) * 240,
      y: (index ~/ 4) * 180,
    );
    project!.interactiveFiction.nodes.add(node);
    selectedIfNode = node;
    changed();
    return node;
  }

  void updateIfNode(
    IfNode node, {
    String? title,
    String? content,
    bool? ending,
  }) {
    if (title != null && title.trim().isNotEmpty) node.title = title.trim();
    if (content != null) node.content = content;
    if (ending != null) node.isEnding = ending;
    changed();
  }

  void setIfStart(IfNode node) {
    project!.interactiveFiction.startNodeId = node.id;
    changed();
  }

  IfChoice addIfChoice(IfNode node) {
    final choice = IfChoice(id: _uuid.v4(), label: 'Continue');
    node.choices.add(choice);
    changed();
    return choice;
  }

  void updateIfChoice(
    IfChoice choice, {
    String? label,
    String? targetNodeId,
    String? condition,
  }) {
    if (label != null) choice.label = label;
    if (targetNodeId != null) {
      choice.targetNodeId = targetNodeId.isEmpty ? null : targetNodeId;
    }
    if (condition != null) choice.condition = condition;
    changed();
  }

  void deleteIfChoice(IfNode node, IfChoice choice) {
    node.choices.remove(choice);
    changed();
  }

  void addIfEffect(IfNode node) {
    node.effects.add(IfEffect(variable: '', expression: ''));
    changed();
  }

  void setIfVariable(String name, String initialValue) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    project!.interactiveFiction.variables[clean] = initialValue.trim();
    changed();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
