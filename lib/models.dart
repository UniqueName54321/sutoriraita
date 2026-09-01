import 'dart:convert';

enum ProjectType {
  prose('prose', 'Prose'),
  screenplay('screenplay', 'Screenplay'),
  interactiveFiction('interactive_fiction', 'Interactive Fiction');

  const ProjectType(this.key, this.label);
  final String key;
  final String label;

  static ProjectType fromKey(String? value) => values.firstWhere(
    (type) => type.key == value,
    orElse: () => ProjectType.prose,
  );
}

enum ScreenplayElementType {
  sceneHeading('scene_heading', 'Scene heading'),
  action('action', 'Action'),
  character('character', 'Character'),
  dialogue('dialogue', 'Dialogue'),
  parenthetical('parenthetical', 'Parenthetical'),
  transition('transition', 'Transition'),
  shot('shot', 'Shot'),
  lyrics('lyrics', 'Lyrics'),
  note('note', 'Note');

  const ScreenplayElementType(this.key, this.label);
  final String key;
  final String label;
  static ScreenplayElementType fromKey(String? value) => values.firstWhere(
    (type) => type.key == value,
    orElse: () => ScreenplayElementType.action,
  );
}

class ScreenplayElement {
  ScreenplayElement({required this.id, required this.type, this.text = ''});
  final String id;
  ScreenplayElementType type;
  String text;
  Map<String, Object?> toJson() => {'id': id, 'type': type.key, 'text': text};
  factory ScreenplayElement.fromJson(Map<String, Object?> json) =>
      ScreenplayElement(
        id: json['id'] as String,
        type: ScreenplayElementType.fromKey(json['type'] as String?),
        text: json['text'] as String? ?? '',
      );
}

class IfChoice {
  IfChoice({
    required this.id,
    this.label = '',
    this.targetNodeId,
    this.condition,
  });
  final String id;
  String label;
  String? targetNodeId;
  String? condition;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (targetNodeId != null) 'targetNodeId': targetNodeId,
    if (condition?.trim().isNotEmpty == true) 'condition': condition,
  };
  factory IfChoice.fromJson(Map<String, Object?> json) => IfChoice(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    targetNodeId: json['targetNodeId'] as String?,
    condition: json['condition'] as String?,
  );
}

class IfEffect {
  IfEffect({required this.variable, required this.expression});
  String variable;
  String expression;
  Map<String, Object?> toJson() => {
    'variable': variable,
    'expression': expression,
  };
  factory IfEffect.fromJson(Map<String, Object?> json) => IfEffect(
    variable: json['variable'] as String? ?? '',
    expression: json['expression'] as String? ?? '',
  );
}

class IfNode {
  IfNode({
    required this.id,
    required this.title,
    this.content = '',
    this.isEnding = false,
    this.x = 0,
    this.y = 0,
    List<IfChoice>? choices,
    List<IfEffect>? effects,
  }) : choices = choices ?? [],
       effects = effects ?? [];
  final String id;
  String title;
  String content;
  bool isEnding;
  double x;
  double y;
  final List<IfChoice> choices;
  final List<IfEffect> effects;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'isEnding': isEnding,
    'position': {'x': x, 'y': y},
    'choices': choices.map((choice) => choice.toJson()).toList(),
    'effects': effects.map((effect) => effect.toJson()).toList(),
  };
  factory IfNode.fromJson(Map<String, Object?> json) {
    final position = (json['position'] as Map? ?? const {})
        .cast<String, Object?>();
    return IfNode(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled passage',
      content: json['content'] as String? ?? '',
      isEnding: json['isEnding'] as bool? ?? false,
      x: (position['x'] as num?)?.toDouble() ?? 0,
      y: (position['y'] as num?)?.toDouble() ?? 0,
      choices: (json['choices'] as List<Object?>? ?? const [])
          .map(
            (item) => IfChoice.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(),
      effects: (json['effects'] as List<Object?>? ?? const [])
          .map(
            (item) => IfEffect.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(),
    );
  }
}

class SohoIr {
  SohoIr({
    Map<String, String>? variables,
    List<IfNode>? nodes,
    this.startNodeId,
  }) : variables = variables ?? {},
       nodes = nodes ?? [];
  final Map<String, String> variables;
  final List<IfNode> nodes;
  String? startNodeId;
  Map<String, Object?> toJson() => {
    'ir': 'sohoko-sei',
    'version': 1,
    'variables': variables,
    'startNodeId': startNodeId,
    'nodes': nodes.map((node) => node.toJson()).toList(),
  };
  factory SohoIr.fromJson(Map<String, Object?> json) => SohoIr(
    variables: (json['variables'] as Map? ?? const {}).map(
      (k, v) => MapEntry('$k', '$v'),
    ),
    startNodeId: json['startNodeId'] as String?,
    nodes: (json['nodes'] as List<Object?>? ?? const [])
        .map((item) => IfNode.fromJson((item as Map).cast<String, Object?>()))
        .toList(),
  );
}

class StoryProject {
  StoryProject({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    required this.sections,
    this.type = ProjectType.prose,
    Map<String, List<ScreenplayElement>>? screenplay,
    SohoIr? interactiveFiction,
    List<EncyclopediaEntry>? encyclopedia,
    List<String>? genres,
    List<GenrePack>? customGenrePacks,
    Map<String, int>? genrePackVersions,
    this.encyclopediaSchemaVersion = currentEncyclopediaSchemaVersion,
    List<EntryRelation>? relations,
    this.path,
  }) : screenplay = screenplay ?? {},
       interactiveFiction = interactiveFiction ?? SohoIr(),
       encyclopedia = encyclopedia ?? [],
       genres = genres ?? [],
       customGenrePacks = customGenrePacks ?? [],
       genrePackVersions = genrePackVersions ?? {},
       relations = relations ?? [];

  final String id;
  String title;
  String author;
  String language;
  final DateTime createdAt;
  DateTime updatedAt;
  String? path;
  final List<StorySection> sections;
  final ProjectType type;
  final Map<String, List<ScreenplayElement>> screenplay;
  final SohoIr interactiveFiction;
  final List<EncyclopediaEntry> encyclopedia;
  final List<String> genres;
  final List<GenrePack> customGenrePacks;
  final Map<String, int> genrePackVersions;
  final int encyclopediaSchemaVersion;
  static const currentEncyclopediaSchemaVersion = 2;
  final List<EntryRelation> relations;

  int get wordCount =>
      sections.fold(0, (sum, section) => sum + section.wordCount);

  Map<String, Object?> toJson() => {
    'format': 'sutoriraita-project',
    'formatVersion': 1,
    'id': id,
    'title': title,
    'author': author,
    'language': language,
    'projectType': type.key,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'sections': sections.map((section) => section.toJson()).toList(),
    if (type == ProjectType.screenplay)
      'screenplay': screenplay.map(
        (sceneId, elements) => MapEntry(
          sceneId,
          elements.map((element) => element.toJson()).toList(),
        ),
      ),
    if (type == ProjectType.interactiveFiction)
      'interactiveFiction': interactiveFiction.toJson(),
    'encyclopedia': encyclopedia.map((entry) => entry.toJson()).toList(),
    'genres': genres,
    'encyclopediaSchemaVersion': encyclopediaSchemaVersion,
    'genrePackVersions': {
      for (final id in genres) id: genrePackVersions[id] ?? 1,
      for (final pack in customGenrePacks) pack.id: pack.version,
    },
    'customGenrePacks': customGenrePacks.map((pack) => pack.toJson()).toList(),
    'relations': relations.map((relation) => relation.toJson()).toList(),
  };

  factory StoryProject.fromJson(Map<String, Object?> json, {String? path}) {
    return StoryProject(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled project',
      author: json['author'] as String? ?? '',
      language: _normaliseLanguage(json['language'] as String? ?? 'en'),
      type: ProjectType.fromKey(json['projectType'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      path: path,
      sections: (json['sections'] as List<Object?>? ?? const [])
          .map(
            (item) =>
                StorySection.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(),
      screenplay: (json['screenplay'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          '$key',
          (value as List<Object?>)
              .map(
                (item) => ScreenplayElement.fromJson(
                  (item as Map).cast<String, Object?>(),
                ),
              )
              .toList(),
        ),
      ),
      interactiveFiction: SohoIr.fromJson(
        (json['interactiveFiction'] as Map? ?? const {})
            .cast<String, Object?>(),
      ),
      encyclopedia: (json['encyclopedia'] as List<Object?>? ?? const [])
          .map(
            (item) => EncyclopediaEntry.fromJson(
              (item as Map).cast<String, Object?>(),
            ),
          )
          .toList(),
      genres: (json['genres'] as List<Object?>? ?? const []).cast<String>(),
      encyclopediaSchemaVersion: json['encyclopediaSchemaVersion'] as int? ?? 1,
      genrePackVersions: (json['genrePackVersions'] as Map? ?? const {}).map(
        (key, value) => MapEntry('$key', value as int),
      ),
      customGenrePacks: (json['customGenrePacks'] as List<Object?>? ?? const [])
          .map(
            (item) => GenrePack.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(),
      relations: (json['relations'] as List<Object?>? ?? const [])
          .map(
            (item) =>
                EntryRelation.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(),
    );
  }

  String prettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  static String _normaliseLanguage(String value) =>
      switch (value.toLowerCase()) {
        'english' => 'en',
        _ => value,
      };
}

enum EncyclopediaType {
  character(
    'character',
    'Character',
    'A person, creature, AI, or other individual entity',
  ),
  location('location', 'Location', 'A place where things exist or happen'),
  group(
    'group',
    'Group',
    'An organisation, faction, team, family, species, or collective',
  ),
  object(
    'object',
    'Object',
    'A physical item, artifact, device, vehicle, or other thing',
  ),
  event(
    'event',
    'Event',
    'Something important that happened, is happening or will happen',
  ),
  concept(
    'concept',
    'Concept',
    'An idea, system, rule, power, technology, religion, condition or piece of lore',
  ),
  other(
    'other',
    'Other',
    'Anything that does not comfortably fit another type',
  );

  const EncyclopediaType(this.key, this.label, this.description);
  final String key;
  final String label;
  final String description;

  static EncyclopediaType fromKey(String? key) => values.firstWhere(
    (type) => type.key == key,
    orElse: () => EncyclopediaType.other,
  );
}

class EncyclopediaEntry {
  EncyclopediaEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.updatedAt,
    this.subtype,
    Map<String, String>? fields,
  }) : fields = fields ?? {};

  final String id;
  String title;
  EncyclopediaType type;
  String content;
  DateTime updatedAt;
  String? subtype;
  final Map<String, String> fields;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'type': type.key,
    'file': 'encyclopedia/$id.md',
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (subtype != null) 'subtype': subtype,
    'fields': fields,
  };

  factory EncyclopediaEntry.fromJson(Map<String, Object?> json) =>
      EncyclopediaEntry(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled entry',
        type: EncyclopediaType.fromKey(json['type'] as String?),
        content: '',
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        subtype: json['subtype'] as String?,
        fields: (json['fields'] as Map? ?? const {}).map(
          (key, value) => MapEntry('$key', '$value'),
        ),
      );
}

enum RelationKind { symmetric, inversePair, directional }

class EncyclopediaFieldDefinition {
  const EncyclopediaFieldDefinition({
    required this.key,
    required this.label,
    required this.entryType,
    this.subtype,
  });
  final String key;
  final String label;
  final EncyclopediaType entryType;
  final String? subtype;

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'entryType': entryType.key,
    if (subtype != null) 'subtype': subtype,
  };

  factory EncyclopediaFieldDefinition.fromJson(Map<String, Object?> json) =>
      EncyclopediaFieldDefinition(
        key: json['key'] as String,
        label: json['label'] as String,
        entryType: EncyclopediaType.fromKey(json['entryType'] as String?),
        subtype: json['subtype'] as String?,
      );
}

class RelationTypeDefinition {
  const RelationTypeDefinition({
    required this.id,
    required this.label,
    required this.kind,
    required this.fromTypes,
    required this.toTypes,
    this.inverseLabel,
    this.fields = const [],
  });
  final String id;
  final String label;
  final String? inverseLabel;
  final RelationKind kind;
  final List<EncyclopediaType> fromTypes;
  final List<EncyclopediaType> toTypes;
  final List<String> fields;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    if (inverseLabel != null) 'inverseLabel': inverseLabel,
    'fromTypes': fromTypes.map((type) => type.key).toList(),
    'toTypes': toTypes.map((type) => type.key).toList(),
    'fields': fields,
  };

  factory RelationTypeDefinition.fromJson(Map<String, Object?> json) =>
      RelationTypeDefinition(
        id: json['id'] as String,
        label: json['label'] as String,
        inverseLabel: json['inverseLabel'] as String?,
        kind: RelationKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => RelationKind.directional,
        ),
        fromTypes: (json['fromTypes'] as List<Object?>? ?? const [])
            .map((value) => EncyclopediaType.fromKey('$value'))
            .toList(),
        toTypes: (json['toTypes'] as List<Object?>? ?? const [])
            .map((value) => EncyclopediaType.fromKey('$value'))
            .toList(),
        fields: (json['fields'] as List<Object?>? ?? const []).cast<String>(),
      );
}

class GenrePack {
  GenrePack({
    required this.id,
    required this.name,
    this.description = '',
    this.version = 1,
    List<EncyclopediaFieldDefinition> fields = const [],
    Map<EncyclopediaType, List<String>> subtypes = const {},
    this.relations = const [],
  }) : fields = fields
           .map(
             (field) => field.subtype == null
                 ? field
                 : EncyclopediaFieldDefinition(
                     key: field.key,
                     label: field.label,
                     entryType: field.entryType,
                     subtype: _normaliseSubtypeId(id, field.subtype!),
                   ),
           )
           .toList(growable: false),
       subtypes = {
         for (final entry in subtypes.entries)
           entry.key: entry.value
               .map((value) => _normaliseSubtypeId(id, value))
               .toList(growable: false),
       };
  final String id;
  final String name;
  final String description;
  final int version;
  final List<EncyclopediaFieldDefinition> fields;
  final Map<EncyclopediaType, List<String>> subtypes;
  final List<RelationTypeDefinition> relations;

  Map<String, Object?> toJson() => {
    'format': 'sutoriraita-genre-pack',
    'formatVersion': 1,
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'version': version,
    'fields': fields.map((field) => field.toJson()).toList(),
    'subtypes': subtypes.map((type, values) => MapEntry(type.key, values)),
    'relations': relations.map((relation) => relation.toJson()).toList(),
  };

  factory GenrePack.fromJson(Map<String, Object?> json) {
    if (json['format'] != 'sutoriraita-genre-pack' ||
        (json['formatVersion'] as int? ?? 0) != 1) {
      throw const FormatException('Unsupported Sutōrīraitā genre pack.');
    }
    const allowedKeys = {
      'format',
      'formatVersion',
      'id',
      'name',
      'description',
      'version',
      'fields',
      'subtypes',
      'relations',
    };
    final unknownKeys = json.keys.where((key) => !allowedKeys.contains(key));
    if (unknownKeys.isNotEmpty) {
      throw FormatException(
        'Genre packs are declarative; unsupported property: ${unknownKeys.first}',
      );
    }
    final topLevelTypes = EncyclopediaType.values
        .map((type) => type.key)
        .toSet();
    final subtypeKeys = (json['subtypes'] as Map? ?? const {}).keys.map(
      (key) => '$key',
    );
    final fieldTypes = (json['fields'] as List<Object?>? ?? const []).map(
      (item) => '${(item as Map)['entryType']}',
    );
    final relationTypes = (json['relations'] as List<Object?>? ?? const [])
        .expand((item) sync* {
          final relation = item as Map;
          yield* (relation['fromTypes'] as List<Object?>? ?? const []).map(
            (type) => '$type',
          );
          yield* (relation['toTypes'] as List<Object?>? ?? const []).map(
            (type) => '$type',
          );
        });
    final invalidType = [
      ...subtypeKeys,
      ...fieldTypes,
      ...relationTypes,
    ].where((key) => !topLevelTypes.contains(key)).firstOrNull;
    if (invalidType != null) {
      throw FormatException(
        'Genre packs cannot create the top-level encyclopedia type "$invalidType".',
      );
    }
    return GenrePack(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      fields: (json['fields'] as List<Object?>? ?? const [])
          .map(
            (item) => EncyclopediaFieldDefinition.fromJson(
              (item as Map).cast<String, Object?>(),
            ),
          )
          .toList(),
      subtypes: (json['subtypes'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          EncyclopediaType.fromKey('$key'),
          (value as List<Object?>).cast<String>(),
        ),
      ),
      relations: (json['relations'] as List<Object?>? ?? const [])
          .map(
            (item) => RelationTypeDefinition.fromJson(
              (item as Map).cast<String, Object?>(),
            ),
          )
          .toList(),
    );
  }

  static String _normaliseSubtypeId(String packId, String value) =>
      value.contains('.') ? value : '$packId.${_slug(value)}';

  static String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

class EntryRelation {
  EntryRelation({
    required this.id,
    required this.fromEntryId,
    required this.toEntryId,
    required this.relationTypeId,
    Map<String, String>? fields,
  }) : fields = fields ?? {};
  final String id;
  final String fromEntryId;
  final String toEntryId;
  final String relationTypeId;
  final Map<String, String> fields;

  Map<String, Object?> toJson() => {
    'id': id,
    'fromEntryId': fromEntryId,
    'toEntryId': toEntryId,
    'relationTypeId': relationTypeId,
    'fields': fields,
  };

  factory EntryRelation.fromJson(Map<String, Object?> json) => EntryRelation(
    id: json['id'] as String,
    fromEntryId: json['fromEntryId'] as String,
    toEntryId: json['toEntryId'] as String,
    relationTypeId: json['relationTypeId'] as String,
    fields: (json['fields'] as Map? ?? const {}).map(
      (key, value) => MapEntry('$key', '$value'),
    ),
  );
}

class ProjectSummary {
  const ProjectSummary({
    required this.path,
    required this.title,
    required this.author,
    required this.updatedAt,
    required this.wordCount,
  });

  final String path;
  final String title;
  final String author;
  final DateTime updatedAt;
  final int wordCount;
}

class StorySection {
  StorySection({required this.id, required this.title, required this.scenes});

  final String id;
  String title;
  final List<StoryScene> scenes;

  int get wordCount => scenes.fold(0, (sum, scene) => sum + scene.wordCount);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'scenes': scenes.map((scene) => scene.toJson()).toList(),
  };

  factory StorySection.fromJson(Map<String, Object?> json) => StorySection(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled chapter',
    scenes: (json['scenes'] as List<Object?>? ?? const [])
        .map(
          (item) => StoryScene.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(),
  );
}

class StoryScene {
  StoryScene({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  String title;
  String content;
  DateTime updatedAt;

  int get wordCount {
    final clean = content.trim();
    return clean.isEmpty ? 0 : clean.split(RegExp(r'\s+')).length;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'file': 'scenes/$id.md',
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory StoryScene.fromJson(
    Map<String, Object?> json, {
    String content = '',
  }) => StoryScene(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled scene',
    content: content,
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
