import 'models.dart';

class EntitySuggestion {
  const EntitySuggestion({
    required this.title,
    required this.type,
    required this.mentions,
  });
  final String title;
  final EncyclopediaType type;
  final int mentions;
}

class EntityDetector {
  static const _ignored = {
    'A',
    'An',
    'And',
    'At',
    'But',
    'Chapter',
    'Ctrl',
    'Exactly',
    'Fine',
    'For',
    'From',
    'I',
    'If',
    'In',
    'It',
    'Markdown',
    'No',
    'Now',
    'One',
    'Opening',
    'Project',
    'Scene',
    'She',
    'Sir',
    'Some',
    'Something',
    'That',
    'The',
    'This',
    'Today',
    'Tomorrow',
    'Tutorial',
    'Use',
    'When',
    'Yesterday',
    'You',
    'Your',
  };
  static const _locationWords = {
    'laundromat',
    'city',
    'town',
    'village',
    'forest',
    'station',
    'school',
    'house',
    'harbour',
    'harbor',
    'street',
    'room',
    'planet',
    'kingdom',
  };
  static const _groupWords = {
    'guild',
    'council',
    'team',
    'family',
    'clan',
    'company',
    'crew',
    'pack',
    'society',
    'order',
    'faction',
    'collective',
    'group',
  };
  static const _objectWords = {
    'sword',
    'device',
    'trolley',
    'car',
    'ship',
    'key',
    'ring',
    'book',
    'artifact',
    'phone',
    'drive',
    'machine',
  };
  static const _eventWords = {
    'war',
    'festival',
    'incident',
    'accident',
    'revolution',
    'election',
    'battle',
    'storm',
    'ceremony',
    'disaster',
  };

  List<EntitySuggestion> detect(
    StoryProject project, {
    bool experimentalObjectsAndEvents = false,
  }) {
    final detected = <_DetectedEntity>[];
    final pattern = RegExp(
      r"\b[A-Z][\p{L}\p{M}'’-]*(?:\s+[A-Z][\p{L}\p{M}'’-]*){0,3}",
      unicode: true,
    );
    for (final scene in project.sections.expand((section) => section.scenes)) {
      for (final match in pattern.allMatches(scene.content)) {
        final value = match
            .group(0)!
            .trim()
            .replaceAll(RegExp(r'[.,!?;:]+$'), '');
        if (value.length < 2 || _ignored.contains(value)) continue;
        final aliases = _aliases(value);
        final existingCandidate = detected.cast<_DetectedEntity?>().firstWhere(
          (candidate) => candidate!.aliases.any(aliases.contains),
          orElse: () => null,
        );
        if (existingCandidate == null) {
          detected.add(_DetectedEntity(title: value, aliases: aliases));
        } else {
          existingCandidate.mentions++;
          if (_displayScore(value) < _displayScore(existingCandidate.title)) {
            existingCandidate.title = value;
          }
          existingCandidate.aliases.addAll(aliases);
        }
      }
    }
    final existing = project.encyclopedia
        .expand((entry) => [entry.title, ...entry.aliases].expand(_aliases))
        .toSet();
    final suggestions = <EntitySuggestion>[];
    for (final candidate in detected) {
      if (candidate.mentions < 2 || candidate.aliases.any(existing.contains)) {
        continue;
      }
      final words = candidate.title.toLowerCase().split(' ');
      EncyclopediaType type;
      if (words.any(_locationWords.contains)) {
        type = EncyclopediaType.location;
      } else if (words.any(_groupWords.contains)) {
        type = EncyclopediaType.group;
      } else if (experimentalObjectsAndEvents &&
          words.any(_objectWords.contains)) {
        type = EncyclopediaType.object;
      } else if (experimentalObjectsAndEvents &&
          words.any(_eventWords.contains)) {
        type = EncyclopediaType.event;
      } else {
        type = EncyclopediaType.character;
      }
      suggestions.add(
        EntitySuggestion(
          title: candidate.title,
          type: type,
          mentions: candidate.mentions,
        ),
      );
    }
    suggestions.sort(
      (a, b) => b.mentions != a.mentions
          ? b.mentions.compareTo(a.mentions)
          : a.title.compareTo(b.title),
    );
    return suggestions;
  }

  Set<String> _aliases(String value) {
    var base = value
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(
          RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}']+$", unicode: true),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ');
    base = base.replaceFirst(RegExp(r'^(?:the|a|an)\s+'), '');
    final aliases = <String>{base};
    final possessive = base.replaceFirst(RegExp(r"(?:'s|s')$"), '');
    aliases.add(possessive);
    final words = possessive.split(' ');
    final last = words.last;
    String? singular;
    if (last.endsWith('ies') && last.length > 3) {
      singular = '${last.substring(0, last.length - 3)}y';
    } else if (last.endsWith('ves') && last.length > 3) {
      singular = '${last.substring(0, last.length - 3)}f';
    } else if (last.endsWith('es') &&
        RegExp(r'(ches|shes|xes|zes|ses)$').hasMatch(last)) {
      singular = last.substring(0, last.length - 2);
    } else if (last.endsWith('s') &&
        last.length > 3 &&
        !RegExp(r'(ss|us|is)$').hasMatch(last)) {
      singular = last.substring(0, last.length - 1);
    }
    if (singular != null) {
      aliases.add([...words.take(words.length - 1), singular].join(' '));
    }
    return aliases.where((alias) => alias.isNotEmpty).toSet();
  }

  int _displayScore(String value) {
    final possessivePenalty = RegExp(r"(?:['’]s|s['’])$").hasMatch(value)
        ? 1000
        : 0;
    final articlePenalty = RegExp(r'^(?:The|A|An)\s+').hasMatch(value)
        ? 100
        : 0;
    return possessivePenalty + articlePenalty + value.length;
  }
}

class _DetectedEntity {
  _DetectedEntity({required this.title, required this.aliases});
  String title;
  final Set<String> aliases;
  int mentions = 1;
}
