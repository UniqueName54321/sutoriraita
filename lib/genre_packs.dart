import 'models.dart';

class GenrePacks {
  static String descriptionFor(GenrePack pack) {
    if (pack.description.trim().isNotEmpty) return pack.description.trim();
    return switch (pack.id) {
      'mystery' =>
        'Clues, suspects, cases, alibis, and investigative relationships.',
      'romance' => 'Attraction, compatibility, relationship status, rivals, and former partners.',
      'horror' =>
        'Threats, victims, hauntings, weaknesses, and escalating danger.',
      'historical' =>
        'Periods, rank, titles, dates, institutions, and historical context.',
      'crime-thriller' =>
        'Criminal roles, investigations, targets, evidence, and pursuit.',
      'post-apocalyptic' => 'Survivors, settlements, scarcity, hazards, and damaged infrastructure.',
      'superhero' =>
        'Heroes, villains, identities, powers, weaknesses, and team dynamics.',
      'adventure' => 'Quests, expeditions, objectives, rewards, hazards, and travelling parties.',
      'slice-of-life' => 'Daily routines, work, school, hobbies, households, and community ties.',
      'dystopian' => 'Control, caste, surveillance, restrictions, privilege, and resistance.',
      'science-fiction' => 'Aliens, planets, starships, advanced technology, and scientific ideas.',
      'fantasy' =>
        'Magic, realms, artifacts, mythical beings, kingdoms, and prophecies.',
      _ =>
        'Imported declarative genre schema with custom fields and relations.',
    };
  }

  static const baseFields = <EncyclopediaFieldDefinition>[
    EncyclopediaFieldDefinition(
      key: 'role',
      label: 'Role',
      entryType: EncyclopediaType.character,
    ),
    EncyclopediaFieldDefinition(
      key: 'pronouns',
      label: 'Pronouns',
      entryType: EncyclopediaType.character,
    ),
    EncyclopediaFieldDefinition(
      key: 'occupation',
      label: 'Occupation',
      entryType: EncyclopediaType.character,
    ),
    EncyclopediaFieldDefinition(
      key: 'appearance',
      label: 'Appearance',
      entryType: EncyclopediaType.character,
    ),
    EncyclopediaFieldDefinition(
      key: 'goals',
      label: 'Goals',
      entryType: EncyclopediaType.character,
    ),
    EncyclopediaFieldDefinition(
      key: 'region',
      label: 'Region',
      entryType: EncyclopediaType.location,
    ),
    EncyclopediaFieldDefinition(
      key: 'purpose',
      label: 'Purpose',
      entryType: EncyclopediaType.location,
    ),
    EncyclopediaFieldDefinition(
      key: 'leadership',
      label: 'Leadership',
      entryType: EncyclopediaType.group,
    ),
    EncyclopediaFieldDefinition(
      key: 'purpose',
      label: 'Purpose',
      entryType: EncyclopediaType.group,
    ),
    EncyclopediaFieldDefinition(
      key: 'owner',
      label: 'Owner',
      entryType: EncyclopediaType.object,
    ),
    EncyclopediaFieldDefinition(
      key: 'function',
      label: 'Function',
      entryType: EncyclopediaType.object,
    ),
    EncyclopediaFieldDefinition(
      key: 'date',
      label: 'Date',
      entryType: EncyclopediaType.event,
    ),
    EncyclopediaFieldDefinition(
      key: 'outcome',
      label: 'Outcome',
      entryType: EncyclopediaType.event,
    ),
    EncyclopediaFieldDefinition(
      key: 'definition',
      label: 'Definition',
      entryType: EncyclopediaType.concept,
    ),
    EncyclopediaFieldDefinition(
      key: 'rules',
      label: 'Rules',
      entryType: EncyclopediaType.concept,
    ),
    EncyclopediaFieldDefinition(
      key: 'category',
      label: 'Category',
      entryType: EncyclopediaType.other,
    ),
  ];

  static const baseRelations = <RelationTypeDefinition>[
    RelationTypeDefinition(
      id: 'friend',
      label: 'friend of',
      kind: RelationKind.symmetric,
      fromTypes: [EncyclopediaType.character],
      toTypes: [EncyclopediaType.character],
      fields: ['since', 'notes'],
    ),
    RelationTypeDefinition(
      id: 'sibling',
      label: 'sibling of',
      kind: RelationKind.symmetric,
      fromTypes: [EncyclopediaType.character],
      toTypes: [EncyclopediaType.character],
    ),
    RelationTypeDefinition(
      id: 'partner',
      label: 'romantic partner of',
      kind: RelationKind.symmetric,
      fromTypes: [EncyclopediaType.character],
      toTypes: [EncyclopediaType.character],
      fields: ['status', 'since'],
    ),
    RelationTypeDefinition(
      id: 'neighbor',
      label: 'neighbor of',
      kind: RelationKind.symmetric,
      fromTypes: [EncyclopediaType.character, EncyclopediaType.location],
      toTypes: [EncyclopediaType.character, EncyclopediaType.location],
    ),
    RelationTypeDefinition(
      id: 'parent',
      label: 'parent of',
      inverseLabel: 'child of',
      kind: RelationKind.inversePair,
      fromTypes: [EncyclopediaType.character],
      toTypes: [EncyclopediaType.character],
    ),
    RelationTypeDefinition(
      id: 'employer',
      label: 'employer of',
      inverseLabel: 'employed by',
      kind: RelationKind.inversePair,
      fromTypes: [EncyclopediaType.character, EncyclopediaType.group],
      toTypes: [EncyclopediaType.character],
    ),
    RelationTypeDefinition(
      id: 'leader',
      label: 'leader of',
      inverseLabel: 'led by',
      kind: RelationKind.inversePair,
      fromTypes: [EncyclopediaType.character],
      toTypes: [EncyclopediaType.group],
    ),
    RelationTypeDefinition(
      id: 'member',
      label: 'member of',
      inverseLabel: 'has member',
      kind: RelationKind.inversePair,
      fromTypes: [EncyclopediaType.character],
      toTypes: [EncyclopediaType.group],
    ),
    RelationTypeDefinition(
      id: 'located',
      label: 'located in',
      inverseLabel: 'contains',
      kind: RelationKind.inversePair,
      fromTypes: [
        EncyclopediaType.location,
        EncyclopediaType.group,
        EncyclopediaType.object,
      ],
      toTypes: [EncyclopediaType.location],
    ),
    RelationTypeDefinition(
      id: 'created',
      label: 'created',
      kind: RelationKind.directional,
      fromTypes: [EncyclopediaType.character, EncyclopediaType.group],
      toTypes: [EncyclopediaType.object, EncyclopediaType.concept],
    ),
    RelationTypeDefinition(
      id: 'worships',
      label: 'worships',
      kind: RelationKind.directional,
      fromTypes: [EncyclopediaType.character, EncyclopediaType.group],
      toTypes: [EncyclopediaType.character, EncyclopediaType.concept],
    ),
    RelationTypeDefinition(
      id: 'knows-about',
      label: 'knows about',
      kind: RelationKind.directional,
      fromTypes: [EncyclopediaType.character, EncyclopediaType.group],
      toTypes: EncyclopediaType.values,
    ),
  ];

  static final builtIns = <GenrePack>[
    GenrePack(
      id: 'mystery',
      name: 'Mystery',
      subtypes: const {
        EncyclopediaType.character: ['Suspect'],
        EncyclopediaType.object: ['Clue'],
        EncyclopediaType.location: ['Crime scene'],
        EncyclopediaType.event: ['Case'],
      },
      fields: [
        _f('mystery', 'alibi', 'Alibi', EncyclopediaType.character),
        _f('mystery', 'motive', 'Motive', EncyclopediaType.character),
        _f('mystery', 'clueStatus', 'Clue status', EncyclopediaType.object),
        _f('mystery', 'caseStatus', 'Case status', EncyclopediaType.event),
      ],
      relations: [
        _r(
          'mystery.suspects',
          'suspects',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['reason', 'confidence'],
        ),
        _r(
          'mystery.witnessed',
          'witnessed',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.event],
          fields: ['account', 'reliability'],
        ),
        _r(
          'mystery.contradicts',
          'contradicts',
          RelationKind.symmetric,
          [EncyclopediaType.object],
          [EncyclopediaType.object],
          fields: ['notes'],
        ),
      ],
    ),
    GenrePack(
      id: 'romance',
      name: 'Romance',
      subtypes: const {
        EncyclopediaType.character: ['Love interest', 'Ex', 'Rival'],
      },
      fields: [
        _f(
          'romance',
          'relationshipStatus',
          'Relationship status',
          EncyclopediaType.character,
        ),
        _f('romance', 'attraction', 'Attraction', EncyclopediaType.character),
        _f(
          'romance',
          'compatibilityNotes',
          'Compatibility notes',
          EncyclopediaType.character,
        ),
      ],
      relations: [
        _r(
          'romance.dating',
          'dating',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['since', 'status'],
        ),
        _r(
          'romance.ex-of',
          'ex of',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['ended', 'reason'],
        ),
        _r(
          'romance.crush-on',
          'has a crush on',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['since', 'awareness'],
        ),
      ],
    ),
    GenrePack(
      id: 'horror',
      name: 'Horror',
      subtypes: const {
        EncyclopediaType.character: ['Monster'],
        EncyclopediaType.object: ['Cursed object'],
        EncyclopediaType.location: ['Haunted location'],
      },
      fields: [
        _f('horror', 'dangerLevel', 'Danger level', EncyclopediaType.character),
        _f(
          'horror',
          'triggerConditions',
          'Trigger conditions',
          EncyclopediaType.object,
        ),
        _f('horror', 'weaknesses', 'Weaknesses', EncyclopediaType.character),
      ],
      relations: [
        _r(
          'horror.haunts',
          'haunts',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.location],
        ),
        _r(
          'horror.possesses',
          'possesses',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.concept],
          [EncyclopediaType.character, EncyclopediaType.object],
        ),
        _r(
          'horror.fears',
          'fears',
          RelationKind.directional,
          [EncyclopediaType.character],
          [
            EncyclopediaType.character,
            EncyclopediaType.object,
            EncyclopediaType.concept,
          ],
        ),
      ],
    ),
    GenrePack(
      id: 'historical',
      name: 'Historical',
      subtypes: const {
        EncyclopediaType.group: ['Dynasty', 'Regiment'],
        EncyclopediaType.location: ['Estate'],
        EncyclopediaType.other: ['Historical office'],
      },
      fields: [
        _f('historical', 'dates', 'Dates', EncyclopediaType.event),
        _f('historical', 'rank', 'Rank', EncyclopediaType.character),
        _f('historical', 'title', 'Title', EncyclopediaType.character),
        _f(
          'historical',
          'socialClass',
          'Social class',
          EncyclopediaType.character,
        ),
      ],
      relations: [
        _r(
          'historical.succeeds',
          'succeeds',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.character, EncyclopediaType.group],
        ),
        _r(
          'historical.serves-under',
          'serves under',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.character, EncyclopediaType.group],
        ),
        _r(
          'historical.inherits-from',
          'inherits from',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['inheritance'],
        ),
      ],
    ),
    GenrePack(
      id: 'crime-thriller',
      name: 'Crime / Thriller',
      subtypes: const {
        EncyclopediaType.group: ['Gang', 'Agency'],
        EncyclopediaType.character: ['Target'],
        EncyclopediaType.event: ['Operation'],
      },
      fields: [
        _f(
          'crime-thriller',
          'wantedStatus',
          'Wanted status',
          EncyclopediaType.character,
        ),
        _f(
          'crime-thriller',
          'clearance',
          'Clearance',
          EncyclopediaType.character,
        ),
        _f(
          'crime-thriller',
          'coverIdentity',
          'Cover identity',
          EncyclopediaType.character,
        ),
      ],
      relations: [
        _r(
          'crime-thriller.investigates',
          'investigates',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [
            EncyclopediaType.character,
            EncyclopediaType.group,
            EncyclopediaType.event,
          ],
        ),
        _r(
          'crime-thriller.blackmails',
          'blackmails',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.character, EncyclopediaType.group],
          fields: ['leverage'],
        ),
        _r(
          'crime-thriller.undercover-for',
          'works undercover for',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.group],
          fields: ['cover', 'status'],
        ),
      ],
    ),
    GenrePack(
      id: 'post-apocalyptic',
      name: 'Post-Apocalyptic',
      subtypes: const {
        EncyclopediaType.location: ['Settlement', 'Wasteland zone'],
        EncyclopediaType.group: ['Survivor group'],
      },
      fields: [
        _f(
          'post-apocalyptic',
          'population',
          'Population',
          EncyclopediaType.location,
        ),
        _f(
          'post-apocalyptic',
          'supplies',
          'Supplies',
          EncyclopediaType.location,
        ),
        _f(
          'post-apocalyptic',
          'hazardType',
          'Hazard type',
          EncyclopediaType.location,
        ),
      ],
      relations: [
        _r(
          'post-apocalyptic.trades-with',
          'trades with',
          RelationKind.symmetric,
          [EncyclopediaType.group, EncyclopediaType.location],
          [EncyclopediaType.group, EncyclopediaType.location],
          fields: ['goods'],
        ),
        _r(
          'post-apocalyptic.raids',
          'raids',
          RelationKind.directional,
          [EncyclopediaType.group],
          [EncyclopediaType.group, EncyclopediaType.location],
        ),
        _r(
          'post-apocalyptic.controls',
          'controls',
          RelationKind.directional,
          [EncyclopediaType.group],
          [EncyclopediaType.location, EncyclopediaType.object],
        ),
      ],
    ),
    GenrePack(
      id: 'superhero',
      name: 'Superhero',
      subtypes: const {
        EncyclopediaType.character: ['Hero', 'Villain', 'Vigilante'],
        EncyclopediaType.group: ['Super-team'],
      },
      fields: [
        _f('superhero', 'powers', 'Powers', EncyclopediaType.character),
        _f('superhero', 'weaknesses', 'Weaknesses', EncyclopediaType.character),
        _f(
          'superhero',
          'secretIdentity',
          'Secret identity',
          EncyclopediaType.character,
        ),
      ],
      relations: [
        _r(
          'superhero.nemesis-of',
          'nemesis of',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
        ),
        _r(
          'superhero.mentors',
          'mentors',
          RelationKind.inversePair,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          inverseLabel: 'mentored by',
        ),
        _r(
          'superhero.unmasked-by',
          'unmasked by',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.character, EncyclopediaType.group],
        ),
      ],
    ),
    GenrePack(
      id: 'adventure',
      name: 'Adventure',
      subtypes: const {
        EncyclopediaType.event: ['Expedition', 'Quest objective'],
        EncyclopediaType.location: ['Landmark'],
      },
      fields: [
        _f('adventure', 'objective', 'Objective', EncyclopediaType.event),
        _f('adventure', 'reward', 'Reward', EncyclopediaType.event),
        _f('adventure', 'danger', 'Danger', EncyclopediaType.location),
      ],
      relations: [
        _r(
          'adventure.seeks',
          'seeks',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [
            EncyclopediaType.object,
            EncyclopediaType.location,
            EncyclopediaType.event,
          ],
        ),
        _r(
          'adventure.guards',
          'guards',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.object, EncyclopediaType.location],
        ),
        _r(
          'adventure.travels-with',
          'travels with',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['journey'],
        ),
      ],
    ),
    GenrePack(
      id: 'slice-of-life',
      name: 'Slice of Life',
      subtypes: const {
        EncyclopediaType.group: ['Class', 'Workplace', 'Club', 'Household'],
      },
      fields: [
        _f(
          'slice-of-life',
          'occupation',
          'Occupation',
          EncyclopediaType.character,
        ),
        _f(
          'slice-of-life',
          'timetable',
          'Timetable',
          EncyclopediaType.character,
        ),
        _f('slice-of-life', 'hobbies', 'Hobbies', EncyclopediaType.character),
      ],
      relations: [
        _r(
          'slice-of-life.coworker-of',
          'coworker of',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['workplace'],
        ),
        _r(
          'slice-of-life.classmate-of',
          'classmate of',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['class'],
        ),
        _r(
          'slice-of-life.lives-with',
          'lives with',
          RelationKind.symmetric,
          [EncyclopediaType.character],
          [EncyclopediaType.character],
          fields: ['household'],
        ),
      ],
    ),
    GenrePack(
      id: 'dystopian',
      name: 'Dystopian',
      subtypes: const {
        EncyclopediaType.group: ['Caste', 'Ministry', 'Resistance cell'],
      },
      fields: [
        _f(
          'dystopian',
          'legalStatus',
          'Legal status',
          EncyclopediaType.character,
        ),
        _f(
          'dystopian',
          'privilegeLevel',
          'Privilege level',
          EncyclopediaType.character,
        ),
        _f(
          'dystopian',
          'restrictions',
          'Restrictions',
          EncyclopediaType.character,
        ),
      ],
      relations: [
        _r(
          'dystopian.controls',
          'controls',
          RelationKind.directional,
          [EncyclopediaType.group],
          [
            EncyclopediaType.character,
            EncyclopediaType.group,
            EncyclopediaType.location,
          ],
        ),
        _r(
          'dystopian.monitors',
          'monitors',
          RelationKind.directional,
          [EncyclopediaType.group],
          [EncyclopediaType.character, EncyclopediaType.group],
        ),
        _r(
          'dystopian.rebels-against',
          'rebels against',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.group],
        ),
      ],
    ),
    GenrePack(
      id: 'science-fiction',
      name: 'Science Fiction',
      subtypes: const {
        EncyclopediaType.character: ['Android', 'Alien', 'Clone'],
        EncyclopediaType.location: ['Planet', 'Space station', 'Starship'],
        EncyclopediaType.group: ['Interstellar faction'],
        EncyclopediaType.object: ['Technology'],
        EncyclopediaType.concept: ['Scientific theory'],
      },
      fields: [
        _f('science-fiction', 'species', 'Species', EncyclopediaType.character),
        _f(
          'science-fiction',
          'homeworld',
          'Homeworld',
          EncyclopediaType.character,
        ),
        _f(
          'science-fiction',
          'technologyLevel',
          'Technology level',
          EncyclopediaType.group,
        ),
        _f(
          'science-fiction',
          'atmosphere',
          'Atmosphere',
          EncyclopediaType.location,
        ),
        _f(
          'science-fiction',
          'operatingPrinciple',
          'Operating principle',
          EncyclopediaType.object,
        ),
        _f(
          'science-fiction',
          'limitations',
          'Limitations',
          EncyclopediaType.concept,
        ),
      ],
      relations: [
        _r(
          'science-fiction.created-by',
          'created by',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.object],
          [EncyclopediaType.character, EncyclopediaType.group],
        ),
        _r(
          'science-fiction.native-to',
          'native to',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.location],
        ),
        _r(
          'science-fiction.powered-by',
          'powered by',
          RelationKind.directional,
          [EncyclopediaType.object, EncyclopediaType.location],
          [EncyclopediaType.object, EncyclopediaType.concept],
        ),
      ],
    ),
    GenrePack(
      id: 'fantasy',
      name: 'Fantasy',
      subtypes: const {
        EncyclopediaType.character: ['Mage', 'Deity', 'Mythical creature'],
        EncyclopediaType.location: ['Realm', 'Sacred site'],
        EncyclopediaType.group: ['Order', 'Kingdom'],
        EncyclopediaType.object: ['Artifact'],
        EncyclopediaType.concept: ['Magic system', 'Prophecy'],
      },
      fields: [
        _f('fantasy', 'ancestry', 'Ancestry', EncyclopediaType.character),
        _f(
          'fantasy',
          'magicalAbilities',
          'Magical abilities',
          EncyclopediaType.character,
        ),
        _f('fantasy', 'domain', 'Domain', EncyclopediaType.character),
        _f('fantasy', 'ruler', 'Ruler', EncyclopediaType.location),
        _f(
          'fantasy',
          'magicalProperties',
          'Magical properties',
          EncyclopediaType.object,
        ),
        _f('fantasy', 'cost', 'Cost', EncyclopediaType.concept),
        _f('fantasy', 'limits', 'Limits', EncyclopediaType.concept),
      ],
      relations: [
        _r(
          'fantasy.sworn-to',
          'sworn to',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.group],
          [EncyclopediaType.character, EncyclopediaType.group],
        ),
        _r(
          'fantasy.wields',
          'wields',
          RelationKind.directional,
          [EncyclopediaType.character],
          [EncyclopediaType.object],
        ),
        _r(
          'fantasy.draws-power-from',
          'draws power from',
          RelationKind.directional,
          [EncyclopediaType.character, EncyclopediaType.object],
          [
            EncyclopediaType.character,
            EncyclopediaType.location,
            EncyclopediaType.concept,
          ],
        ),
      ],
    ),
  ];

  static EncyclopediaFieldDefinition _f(
    String pack,
    String key,
    String label,
    EncyclopediaType type,
  ) => EncyclopediaFieldDefinition(
    key: '$pack.$key',
    label: label,
    entryType: type,
  );

  static RelationTypeDefinition _r(
    String id,
    String label,
    RelationKind kind,
    List<EncyclopediaType> from,
    List<EncyclopediaType> to, {
    String? inverseLabel,
    List<String> fields = const [],
  }) => RelationTypeDefinition(
    id: id,
    label: label,
    inverseLabel: inverseLabel,
    kind: kind,
    fromTypes: from,
    toTypes: to,
    fields: fields,
  );

  static GenrePack? byId(String id) {
    for (final pack in builtIns) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  static List<GenrePack> active(StoryProject project) => [
    for (final id in project.genres) ?byId(id),
    ...project.customGenrePacks,
  ];

  /// Upgrades legacy display-name subtypes without discarding unknown values.
  static void normaliseProjectSchema(StoryProject project) {
    for (final entry in project.encyclopedia) {
      final value = entry.subtype;
      if (value == null || value.contains('.')) continue;
      final slug = value.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '-',
      );
      for (final pack in active(project)) {
        final match = pack.subtypes[entry.type]
            ?.where((id) => id.endsWith('.$slug'))
            .firstOrNull;
        if (match != null) {
          entry.subtype = match;
          break;
        }
      }
    }
  }

  static List<EncyclopediaFieldDefinition> fieldsFor(
    StoryProject project,
    EncyclopediaEntry entry,
  ) {
    final fields = <String, EncyclopediaFieldDefinition>{};
    for (final field in baseFields.where(
      (field) => field.entryType == entry.type,
    )) {
      fields[field.key] = field;
    }
    for (final pack in active(project)) {
      for (final field in pack.fields.where(
        (field) =>
            field.entryType == entry.type &&
            (field.subtype == null || field.subtype == entry.subtype),
      )) {
        final core = baseFields
            .where(
              (base) =>
                  base.entryType == field.entryType &&
                  (base.key == field.key ||
                      field.key.endsWith('.${base.key}') ||
                      base.label.toLowerCase() == field.label.toLowerCase()),
            )
            .firstOrNull;
        fields[core?.key ?? field.key] = core == null
            ? field
            : EncyclopediaFieldDefinition(
                key: core.key,
                label: field.label,
                entryType: field.entryType,
                subtype: field.subtype,
              );
      }
    }
    return fields.values.toList();
  }

  static List<String> subtypesFor(
    StoryProject project,
    EncyclopediaType type,
  ) =>
      {for (final pack in active(project)) ...?pack.subtypes[type]}.toList()
        ..sort();

  static String subtypeLabel(StoryProject project, String subtypeId) {
    for (final pack in active(project)) {
      for (final values in pack.subtypes.values) {
        if (values.contains(subtypeId)) {
          final local = subtypeId.substring(subtypeId.indexOf('.') + 1);
          return local
              .split('-')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' ');
        }
      }
    }
    return subtypeId;
  }

  /// Produces a deliberately simple, editable encyclopedia starting point.
  /// It never invents facts beyond the entry type, subtype, and stored fields.
  static String generateEntryBase(
    StoryProject project,
    EncyclopediaEntry entry,
  ) {
    final definitions = fieldsFor(project, entry);
    final subtype = entry.subtype == null
        ? null
        : subtypeLabel(project, entry.subtype!);
    final identity = subtype ?? entry.type.label;
    final facts = entry.fields.entries
        .where((field) => field.value.trim().isNotEmpty)
        .map((field) {
          final definition = definitions
              .where((candidate) => candidate.key == field.key)
              .firstOrNull;
          final label =
              definition?.label ?? field.key.replaceFirst('custom:', '');
          return '- **$label:** ${field.value.trim()}';
        })
        .join('\n');

    return '''## Overview

${entry.title} is a${RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(identity) ? 'n' : ''} ${identity.toLowerCase()}.

${facts.isEmpty ? '## Details\n\nAdd structured facts to develop this entry.' : '## Details\n\n$facts'}
''';
  }

  static List<RelationTypeDefinition> relationsFor(
    StoryProject project,
    EncyclopediaType from,
    EncyclopediaType to,
  ) => [...baseRelations, for (final pack in active(project)) ...pack.relations]
      .where(
        (relation) =>
            relation.fromTypes.contains(from) && relation.toTypes.contains(to),
      )
      .toList();
}
