import 'dart:convert';
import 'dart:typed_data';

import 'package:toml/toml.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// Hammer dataVersion 2. All input paths are relative, validated by the store.
/// The original files travel with the project, including notes and timelines
/// that do not yet have an editor in Sutōrīraitā.
class HammerFormat {
  static const sourceFile = 'assets/hammer-source.json';
  static const _uuid = Uuid();
  static final _node = RegExp(r'^(\d+)~([^~/\\]+)~(\d+)(\.md)?$');
  static bool _activeScene(String path) =>
      path.startsWith('scenes/') &&
      path.endsWith('.md') &&
      !path.split('/').any((p) => p.startsWith('.'));
  static const _encoded = {
    ':': '꞉',
    '?': '？',
    '/': '⁄',
    '\\': '⧹',
    '*': '∗',
    '"': '＂',
    '|': '｜',
    '<': '‹',
    '>': '›',
  };

  static String decodeName(String name) {
    for (final pair in _encoded.entries) {
      name = name.replaceAll(pair.value, pair.key);
    }
    return name;
  }

  static String encodeName(String name) {
    for (final pair in _encoded.entries) {
      name = name.replaceAll(pair.key, pair.value);
    }
    name = name
        .replaceAll(RegExp(r'[~\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    if (name.isEmpty) name = 'Untitled';
    if (RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(name)) {
      name = '_$name';
    }
    return name.length > 90 ? name.substring(0, 90) : name;
  }

  /// Tomlkt writes null (a TOML extension). Tokenize quoted strings/comments
  /// before adapting null; never rewrite prose that happens to contain it.
  static Map<String, dynamic> parseToml(String source) {
    final tokens = RegExp(
      r'''"""(?:\\[\s\S]|(?!""")[\s\S])*""""{0,2}|'''
      "'''(?:[\\s\\S]*?)'''"
      r'''|"(?:\\[\s\S]|[^"\\])*"|'[^']*'|#[^\r\n]*|\bnull\b''',
    );
    const sentinel = '__sutoriraita_toml_null_9e57__';
    final adapted = source.replaceAllMapped(
      tokens,
      (m) => m[0] == 'null' ? '"$sentinel"' : m[0]!,
    );
    dynamic restore(dynamic value) {
      if (value == sentinel) return null;
      if (value is Map) return value.map((k, v) => MapEntry('$k', restore(v)));
      if (value is List) return value.map(restore).toList();
      return value;
    }

    return (restore(TomlDocument.parse(adapted).toMap()) as Map)
        .cast<String, dynamic>();
  }

  static String _toml(Map<String, dynamic> data) {
    dynamic clean(dynamic value) {
      if (value is Map) {
        return {
          for (final e in value.entries)
            if (e.value != null) e.key: clean(e.value),
        };
      }
      if (value is List) {
        return value.where((v) => v != null).map(clean).toList();
      }
      return value;
    }

    return TomlDocument.fromMap((clean(data) as Map).cast<String, dynamic>())
        .toString();
  }

  static ({StoryProject project, Uint8List source}) decode(
    Map<String, Uint8List> files,
    String title,
  ) {
    String text(String path) => utf8.decode(files[path]!);
    final info = parseToml(text('project.toml'))['info'];
    if (info is! Map || info['dataVersion'] != 2) {
      throw const FormatException(
        'Supported Hammer projects use dataVersion 2.',
      );
    }
    final data = files.containsKey('project_data.toml')
        ? parseToml(text('project_data.toml'))['data'] as Map? ?? {}
        : <String, dynamic>{};
    final now = DateTime.now();
    final project = StoryProject(
      id: _uuid.v4(),
      title: decodeName(title),
      author: data['authorName'] as String? ?? '',
      language: data['language'] as String? ?? 'en',
      createdAt: DateTime.tryParse('${info['created']}') ?? now,
      updatedAt: now,
      sections: [],
    );
    final sectionPaths = <String, String>{};
    final scenePaths = <String, String>{};
    final entryPaths = <String, String>{};
    final sectionTitles = <String, String>{};
    final ids = <int>{};
    final allNodes = <String>{};
    for (final path in files.keys.where(_activeScene)) {
      final parts = path.substring(7).split('/');
      for (var i = 0; i < parts.length; i++) {
        final full = parts.take(i + 1).join('/');
        if (!allNodes.add(full)) continue;
        final match = _node.firstMatch(parts[i]);
        if (match == null || !ids.add(int.parse(match[3]!))) {
          throw FormatException('Invalid or duplicate Hammer scene ID: $path');
        }
      }
    }
    int compare(String a, String b) {
      final aa = a.split('/'), bb = b.split('/');
      for (var i = 0; i < aa.length && i < bb.length; i++) {
        final order = int.parse(_node.firstMatch(aa[i])![1]!)
            .compareTo(int.parse(_node.firstMatch(bb[i])![1]!));
        if (order != 0) return order;
        if (aa[i] != bb[i]) return aa[i].compareTo(bb[i]);
      }
      return aa.length.compareTo(bb.length);
    }

    final sceneFiles = files.keys.where(_activeScene).toList()
      ..sort((a, b) => compare(a.substring(7), b.substring(7)));
    String? previousParent;
    StorySection? section;
    for (final path in sceneFiles) {
      final parts = path.substring(7).split('/');
      final parent = parts.take(parts.length - 1).join('/');
      if (section == null || previousParent != parent) {
        final label = parent.isEmpty
            ? 'Ungrouped scenes'
            : parts
                  .take(parts.length - 1)
                  .map((p) => decodeName(_node.firstMatch(p)![2]!))
                  .join(' / ');
        section = StorySection(id: _uuid.v4(), title: label, scenes: []);
        project.sections.add(section);
        sectionPaths[section.id] = parent;
        sectionTitles[section.id] = label;
        previousParent = parent;
      }
      final scene = StoryScene(
        id: _uuid.v4(),
        title: decodeName(_node.firstMatch(parts.last)![2]!),
        content: text(path),
        updatedAt: now,
      );
      section.scenes.add(scene);
      scenePaths[scene.id] = path;
    }
    if (project.sections.isEmpty) {
      project.sections.add(
        StorySection(id: _uuid.v4(), title: 'Chapter One', scenes: []),
      );
    }
    for (final path in files.keys.where(
      (p) => p.startsWith('encyclopedia/') && p.endsWith('.toml'),
    )) {
      final entry = parseToml(text(path))['entry'];
      if (entry is! Map ||
          entry['id'] is! int ||
          !ids.add(entry['id'] as int)) {
        throw FormatException('Invalid Hammer encyclopedia entry: $path');
      }
      final value = EncyclopediaEntry(
        id: _uuid.v4(),
        title: entry['name'] as String? ?? 'Untitled',
        type: switch (entry['type']) {
          'PERSON' => EncyclopediaType.character,
          'PLACE' => EncyclopediaType.location,
          'THING' => EncyclopediaType.object,
          'EVENT' => EncyclopediaType.event,
          'IDEA' => EncyclopediaType.concept,
          _ => EncyclopediaType.other,
        },
        content: entry['text'] as String? ?? '',
        updatedAt: now,
        fields: {'tags': (entry['tags'] as List? ?? []).join(', ')},
      );
      project.encyclopedia.add(value);
      entryPaths[value.id] = path;
    }
    final source = utf8.encode(
      jsonEncode({
        'files': files.map((k, v) => MapEntry(k, base64Encode(v))),
        'sections': sectionPaths,
        'sectionTitles': sectionTitles,
        'scenes': scenePaths,
        'entries': entryPaths,
        'sectionScenes': {
          for (final s in project.sections)
            s.id: s.scenes.map((v) => v.id).toList(),
        },
      }),
    );
    return (project: project, source: Uint8List.fromList(source));
  }

  static Map<String, Uint8List> encode(
    StoryProject project, {
    Uint8List? source,
  }) {
    final original = source == null
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(source)) as Map;
    final files = <String, Uint8List>{
      for (final e in (original['files'] as Map? ?? {}).entries)
        '${e.key}': base64Decode(e.value as String),
    };
    final sections = original['sections'] as Map? ?? {};
    final titles = original['sectionTitles'] as Map? ?? {};
    final scenes = original['scenes'] as Map? ?? {};
    final entries = original['entries'] as Map? ?? {};
    // Preserve numeric IDs because notes, timeline and scene metadata refer to
    // them. New IDs must be above *all* original IDs, not just scene IDs.
    var nextId = 1;
    for (final path in files.keys) {
      for (final match in RegExp(r'\d+').allMatches(path)) {
        final id = int.tryParse(match[0]!) ?? 0;
        if (id >= nextId) nextId = id + 1;
      }
      if (path.endsWith('.toml')) {
        for (final match in RegExp(
          r'^\s*id\s*=\s*(\d+)',
          multiLine: true,
        ).allMatches(utf8.decode(files[path]!))) {
          final id = int.parse(match[1]!);
          if (id >= nextId) nextId = id + 1;
        }
      }
    }
    for (final path in [...scenes.values, ...entries.values]) {
      files.remove(path);
    }
    void write(String path, String value) {
      files[path] = Uint8List.fromList(utf8.encode(value));
    }

    // Keep untouched nested groups/root scenes when the section arrangement is
    // unchanged. Structural edits export a flat chapter tree in current order.
    final sameStructure =
        project.sections.map((s) => s.id).join('|') ==
            sections.keys.join('|') &&
        project.sections.every(
          (s) =>
              titles[s.id] == s.title &&
              s.scenes.map((v) => v.id).join('|') ==
                  ((original['sectionScenes'] as Map? ?? {})[s.id] as List? ??
                          [])
                      .join('|'),
        );
    for (var i = 0; i < project.sections.length; i++) {
      final section = project.sections[i];
      final parent = sameStructure
          ? sections[section.id] as String
          : '${i.toString().padLeft(4, '0')}~${encodeName(section.title)}~${nextId++}';
      for (var j = 0; j < section.scenes.length; j++) {
        final scene = section.scenes[j];
        final old = scenes[scene.id] as String?;
        final id = old == null
            ? nextId++
            : int.parse(_node.firstMatch(old.split('/').last)![3]!);
        // Root scenes may be interspersed with groups: retain original order.
        final order = sameStructure && old != null
            ? _node.firstMatch(old.split('/').last)![1]!
            : j.toString().padLeft(4, '0');
        write(
          'scenes/${parent.isEmpty ? '' : '$parent/'}$order~${encodeName(scene.title)}~$id.md',
          scene.content,
        );
      }
    }
    for (final entry in project.encyclopedia) {
      final oldPath = entries[entry.id] as String?;
      final raw = oldPath == null
          ? <String, dynamic>{}
          : parseToml(
              utf8.decode(
                base64Decode((original['files'] as Map)[oldPath] as String),
              ),
            );
      final data = (raw['entry'] as Map? ?? {}).cast<String, dynamic>();
      final id = data['id'] as int? ?? nextId++;
      final type = switch (entry.type) {
        EncyclopediaType.character => 'person',
        EncyclopediaType.location => 'place',
        EncyclopediaType.object => 'thing',
        EncyclopediaType.event => 'event',
        _ => 'idea',
      };
      final oldType = (data['type'] as String?)?.toLowerCase();
      if (oldType != null && oldType != type) {
        final image = files.remove(
          'encyclopedia/$oldType/$oldType-$id-image.jpg',
        );
        if (image != null) {
          files['encyclopedia/$type/$type-$id-image.jpg'] = image;
        }
      }
      final oldTags = data['tags'] as List? ?? [];
      data.addAll({
        'id': id,
        'name': entry.title,
        'type': type.toUpperCase(),
        'text': entry.content,
        'tags': oldTags.join(', ') == (entry.fields['tags'] ?? '')
            ? oldTags
            : (entry.fields['tags'] ?? '')
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList(),
      });
      write(
        'encyclopedia/$type/$type-$id-${encodeName(entry.title)}.toml',
        _toml({'entry': data}),
      );
    }
    write(
      'project.toml',
      '[info]\ncreated = ${jsonEncode(project.createdAt.toUtc().toIso8601String())}\nlastAccessed = null\ndataVersion = 2\nserverProjectId = null\n',
    );
    final rawData = files['project_data.toml'];
    final data = rawData == null
        ? <String, dynamic>{}
        : parseToml(utf8.decode(rawData));
    final settings = (data['data'] as Map? ?? {}).cast<String, dynamic>();
    settings.addAll({
      'authorName': project.author,
      'language': project.language,
    });
    write('project_data.toml', _toml({'data': settings}));
    return files;
  }
}
