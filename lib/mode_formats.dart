import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'models.dart';

class FountainFormat {
  static const _uuid = Uuid();

  static List<({String title, List<ScreenplayElement> elements})> decode(
    String source,
  ) {
    final scenes = <({String title, List<ScreenplayElement> elements})>[];
    var title = 'Opening scene';
    var elements = <ScreenplayElement>[];
    final lines = const LineSplitter().convert(source.replaceAll('\r\n', '\n'));
    ScreenplayElementType previous = ScreenplayElementType.action;

    void add(ScreenplayElementType type, String text) {
      elements.add(ScreenplayElement(id: _uuid.v4(), type: type, text: text));
      previous = type;
    }

    void finish() {
      if (elements.isNotEmpty) scenes.add((title: title, elements: elements));
      elements = [];
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      final upper = line.trim().toUpperCase();
      final isHeading = RegExp(r'^(INT\.?|EXT\.?|INT\.?/EXT\.?|I/E\.)\s')
          .hasMatch(upper);
      if (isHeading) {
        finish();
        title = line.trim();
        add(ScreenplayElementType.sceneHeading, line.trim());
      } else if (line.startsWith('>') || upper.endsWith(' TO:')) {
        add(
          ScreenplayElementType.transition,
          line.replaceAll(RegExp(r'^>\s*'), '').trim(),
        );
      } else if (line.startsWith('!')) {
        add(ScreenplayElementType.action, line.substring(1).trimLeft());
      } else if (line.startsWith('.')) {
        add(ScreenplayElementType.sceneHeading, line.substring(1).trimLeft());
      } else if (line.startsWith('(') && line.endsWith(')')) {
        add(ScreenplayElementType.parenthetical, line.trim());
      } else if (line.startsWith('~')) {
        add(ScreenplayElementType.lyrics, line.substring(1));
      } else if (line.startsWith('[[') && line.endsWith(']]')) {
        add(ScreenplayElementType.note, line.substring(2, line.length - 2));
      } else if (line.trim() == upper && RegExp(r'[A-Z]').hasMatch(line)) {
        add(
          ScreenplayElementType.character,
          line.trim().replaceAll(RegExp(r'\^$'), ''),
        );
      } else if (previous == ScreenplayElementType.character ||
          previous == ScreenplayElementType.parenthetical ||
          previous == ScreenplayElementType.dialogue) {
        add(ScreenplayElementType.dialogue, line.trim());
      } else {
        add(ScreenplayElementType.action, line.trim());
      }
    }
    finish();
    if (scenes.isEmpty) {
      scenes.add((
        title: 'Opening scene',
        elements: [
          ScreenplayElement(
            id: _uuid.v4(),
            type: ScreenplayElementType.action,
            text: source.trim(),
          ),
        ],
      ));
    }
    return scenes;
  }

  static String encode(StoryProject project) {
    final output = StringBuffer();
    for (final scene in project.sections.expand((section) => section.scenes)) {
      final elements = project.screenplay[scene.id] ?? const [];
      for (final element in elements) {
        final text = element.text.trim();
        if (text.isEmpty) continue;
        output.writeln(switch (element.type) {
          ScreenplayElementType.sceneHeading => text.toUpperCase(),
          ScreenplayElementType.character => text.toUpperCase(),
          ScreenplayElementType.parenthetical =>
            text.startsWith('(') ? text : '($text)',
          ScreenplayElementType.transition =>
            text.endsWith('TO:') ? text.toUpperCase() : '> $text',
          ScreenplayElementType.lyrics => '~$text',
          ScreenplayElementType.note => '[[$text]]',
          ScreenplayElementType.shot => '!${text.toUpperCase()}',
          ScreenplayElementType.action ||
          ScreenplayElementType.dialogue => text,
        });
        output.writeln();
      }
    }
    return '${output.toString().trimRight()}\n';
  }
}

class SohoInkExporter {
  static String encode(StoryProject project) {
    final ir = project.interactiveFiction;
    final start = ir.nodes
        .where((node) => node.id == ir.startNodeId)
        .firstOrNull;
    if (start == null) {
      throw const FormatException(
        'Sōhōkō-sei has no valid start passage to export.',
      );
    }
    final knotNames = <String, String>{};
    for (final node in ir.nodes) {
      knotNames[node.id] = _friendlyKnotName(node, start: node == start);
    }
    final output = StringBuffer(
      '// Generated from Sōhōkō-sei IR by Sutōrīraitā\n',
    );
    for (final variable in ir.variables.entries) {
      output.writeln(
        'VAR ${_inkId(variable.key)} = ${variable.value.isEmpty ? '0' : variable.value}',
      );
    }
    // Resolve through the same immutable ID map used by every knot and choice.
    // This prevents a displayed/selected node from accidentally becoming entry.
    output.writeln('-> ${knotNames[start.id]}');
    for (final node in ir.nodes) {
      output.writeln('\n=== ${knotNames[node.id]} ===');
      output.writeln('// ${node.title}');
      final scene = ir.scenes
          .where((item) => item.id == node.sceneId)
          .firstOrNull;
      if (scene != null) output.writeln('// Scene: ${scene.title}');
      output.writeln(node.content.trim());
      for (final effect in node.effects) {
        if (effect.variable.trim().isNotEmpty) {
          output.writeln(
            '~ ${_inkId(effect.variable)} = ${effect.expression.isEmpty ? '0' : effect.expression}',
          );
        }
      }
      for (final choice in node.choices) {
        final condition = choice.condition?.trim();
        final prefix = condition?.isNotEmpty == true ? '{$condition} ' : '';
        output.writeln('* $prefix[${choice.label}]');
        final target = knotNames[choice.targetNodeId];
        if (target != null) {
          output.writeln('    -> $target');
        }
      }
      if (node.isEnding || node.choices.isEmpty) output.writeln('-> END');
    }
    return output.toString();
  }

  static String _inkId(String value) {
    final clean = value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return RegExp(r'^[0-9]').hasMatch(clean) ? 'n_$clean' : clean;
  }

  static String _friendlyKnotName(IfNode node, {required bool start}) {
    var slug = node.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) slug = 'passage';
    final rawShort = node.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final short = rawShort.substring(0, rawShort.length.clamp(1, 8));
    final safeShort = _inkId(short);
    return '${start ? 'start_' : ''}${slug}_$safeShort';
  }
}
