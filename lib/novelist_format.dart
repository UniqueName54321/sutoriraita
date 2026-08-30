import 'dart:convert';
import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:uuid/uuid.dart';

import 'models.dart';

/// Novelist's version-4 backup envelope, accepted by its migration importer.
/// This is a story backup, not a compiled manuscript with a renamed extension.
class NovelistFormat {
  static Uint8List encode(StoryProject project) {
    const uuid = Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    final scenes = <Map<String, Object?>>[];
    final sections = <Map<String, Object?>>[];
    for (final section in project.sections) {
      final refs = <Map<String, Object?>>[];
      for (final scene in section.scenes) {
        final code = uuid.v4();
        refs.add({'code': code, 'ranking': refs.length + 1});
        scenes.add({
          'code': code,
          'title': scene.title,
          'synopsis': '',
          'ranking': scenes.length + 1,
          'status': '1',
          'scene_items': [],
          'text': jsonEncode({'blocks': _blocks(scene.content)}),
        });
      }
      sections.add({
        'code': uuid.v4(),
        'title': section.title,
        'synopsis': '',
        'ranking': sections.length + 1,
        'section_scenes': refs,
      });
    }
    final categories = <Map<String, Object?>>[];
    for (final type in EncyclopediaType.values) {
      final entries = project.encyclopedia
          .where((e) => e.type == type)
          .toList();
      if (entries.isEmpty) continue;
      categories.add({
        'code': uuid.v4(),
        'title': type.label,
        'color': 4281826635,
        'ranking': categories.length + 1,
        'metadata_groups': [],
        'items': [
          for (var i = 0; i < entries.length; i++)
            {
              'code': uuid.v4(),
              'title': entries[i].title,
              'synopsis': entries[i].content,
              'ranking': i + 1,
              'status': '1',
              'item_metadatas': [],
            },
        ],
      });
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 4, 'code': uuid.v4(), 'title': project.title,
          'description': project.author.isEmpty ? '' : 'By ${project.author}',
          'show_table_of_contents': true, 'apply_automatic_indentation': true,
          'last_update_date': now,
          'last_cloud_sync_date': 0,
          'last_backup_date': now,
          'revisions': [
            {
              'number': 1,
              'date': now,
              'book_progresses': [],
              'categories': categories,
              'statuses': [
                {
                  'code': '1',
                  'title': 'To do',
                  'color': 4292270041,
                  'ranking': 1,
                },
              ],
              'subplots': [],
              'scenes': scenes,
              'sections': sections,
            },
          ],
          // Optional app-specific metadata: Novelist ignores unknown JSON keys.
          'sutoriraita': {
            'author': project.author,
            'language': project.language,
          },
        }),
      ),
    );
  }

  static List<Map<String, Object?>> _blocks(String markdown) {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parseLines(markdown.split('\n'));
    final blocks = <Map<String, Object?>>[];
    void block(md.Node node) {
      if (node is md.Element && {'ul', 'ol', 'blockquote'}.contains(node.tag)) {
        for (final child in node.children ?? <md.Node>[]) {
          block(child);
        }
        return;
      }
      final text = StringBuffer();
      final spans = <Map<String, Object?>>[];
      void inline(md.Node n) {
        if (n is md.Text) {
          text.write(n.text);
          return;
        }
        if (n is! md.Element) return;
        if (n.tag == 'br') {
          text.write('\n');
          return;
        }
        if (n.tag == 'img') {
          text.write(n.attributes['alt'] ?? '');
          return;
        }
        final start = text.length;
        for (final child in n.children ?? <md.Node>[]) {
          inline(child);
        }
        final type = switch (n.tag) {
          'em' => 'italic',
          'strong' => 'bold',
          _ => null,
        };
        if (type != null && text.length > start) {
          spans.add({'type': type, 'start': start, 'end': text.length});
        }
      }

      inline(node);
      blocks.add({
        'type': 'text',
        'align': 'left',
        'text': text.toString(),
        'spans': spans,
      });
    }

    for (final node in nodes) {
      block(node);
    }
    return blocks;
  }
}
