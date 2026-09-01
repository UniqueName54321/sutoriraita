import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commonmark_view.dart';
import 'models.dart';
import 'project_controller.dart';

ScreenplayElementType _nextElement(ScreenplayElementType current) =>
    switch (current) {
      ScreenplayElementType.sceneHeading => ScreenplayElementType.action,
      ScreenplayElementType.character => ScreenplayElementType.dialogue,
      ScreenplayElementType.parenthetical => ScreenplayElementType.dialogue,
      ScreenplayElementType.dialogue => ScreenplayElementType.character,
      ScreenplayElementType.transition => ScreenplayElementType.sceneHeading,
      _ => ScreenplayElementType.action,
    };

class ScreenplayEditor extends StatelessWidget {
  const ScreenplayEditor({super.key, required this.controller});
  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final scene = controller.selectedScene;
    if (scene == null) {
      return const Center(child: Text('Select a screenplay scene.'));
    }
    final elements = controller.project!.screenplay.putIfAbsent(
      scene.id,
      () => [],
    );
    final characters =
        controller.project!.screenplay.values
            .expand((items) => items)
            .where((item) => item.type == ScreenplayElementType.character)
            .map((item) => item.text.trim().toUpperCase())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Column(
      children: [
        Material(
          color: const Color(0xFFFBFAF6),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.movie_creation_outlined),
            title: Text(
              scene.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text(
              'Enter advances element type · Tab changes element type',
            ),
            trailing: IconButton(
              tooltip: 'Add screenplay element',
              onPressed: () => controller.addScreenplayElement(
                scene,
                elements.length,
                ScreenplayElementType.action,
              ),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 700 ? 12 : 32,
              20,
              MediaQuery.sizeOf(context).width < 700 ? 12 : 32,
              100 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            itemCount: elements.length,
            itemBuilder: (context, index) => _ScreenplayElementRow(
              key: ValueKey(elements[index].id),
              element: elements[index],
              characters: characters,
              onChanged: (text) => controller.updateScreenplayElement(
                elements[index],
                text: text,
              ),
              onType: (type) => controller.updateScreenplayElement(
                elements[index],
                type: type,
              ),
              onSubmit: () => controller.addScreenplayElement(
                scene,
                index + 1,
                _nextElement(elements[index].type),
              ),
              onDelete: () =>
                  controller.deleteScreenplayElement(scene, elements[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenplayElementRow extends StatefulWidget {
  const _ScreenplayElementRow({
    super.key,
    required this.element,
    required this.characters,
    required this.onChanged,
    required this.onType,
    required this.onSubmit,
    required this.onDelete,
  });
  final ScreenplayElement element;
  final List<String> characters;
  final ValueChanged<String> onChanged;
  final ValueChanged<ScreenplayElementType> onType;
  final VoidCallback onSubmit;
  final VoidCallback onDelete;

  @override
  State<_ScreenplayElementRow> createState() => _ScreenplayElementRowState();
}

class _ScreenplayElementRowState extends State<_ScreenplayElementRow> {
  late final text = TextEditingController(text: widget.element.text);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void cycleType() {
    final values = ScreenplayElementType.values;
    widget.onType(
      values[(values.indexOf(widget.element.type) + 1) % values.length],
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.tab): cycleType},
      child: Focus(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 700 ? 54 : 150,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ScreenplayElementType>(
                  isExpanded: true,
                  value: widget.element.type,
                  selectedItemBuilder: (_) => ScreenplayElementType.values
                      .map(
                        (type) => Tooltip(
                          message: type.label,
                          child: Icon(_elementIcon(type)),
                        ),
                      )
                      .toList(),
                  items: ScreenplayElementType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) widget.onType(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: widget.element.type == ScreenplayElementType.character
                  ? Autocomplete<String>(
                      optionsBuilder: (value) => widget.characters.where(
                        (name) => name.contains(value.text.toUpperCase()),
                      ),
                      initialValue: TextEditingValue(text: widget.element.text),
                      onSelected: widget.onChanged,
                      fieldViewBuilder: (context, controller, focus, submit) =>
                          TextField(
                            controller: controller,
                            focusNode: focus,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'CHARACTER',
                            ),
                            onChanged: widget.onChanged,
                            onSubmitted: (_) {
                              submit();
                              widget.onSubmit();
                            },
                          ),
                    )
                  : TextField(
                      controller: text,
                      maxLines:
                          widget.element.type == ScreenplayElementType.action
                          ? null
                          : 3,
                      textCapitalization:
                          widget.element.type ==
                              ScreenplayElementType.sceneHeading
                          ? TextCapitalization.characters
                          : TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: widget.element.type.label,
                      ),
                      onChanged: widget.onChanged,
                      onSubmitted: (_) => widget.onSubmit(),
                    ),
            ),
            IconButton(
              tooltip: 'Delete element',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    ),
  );
}

IconData _elementIcon(ScreenplayElementType type) => switch (type) {
  ScreenplayElementType.sceneHeading => Icons.location_on_outlined,
  ScreenplayElementType.action => Icons.directions_run,
  ScreenplayElementType.character => Icons.person_outline,
  ScreenplayElementType.dialogue => Icons.chat_bubble_outline,
  ScreenplayElementType.parenthetical => Icons.notes,
  ScreenplayElementType.transition => Icons.swap_horiz,
  ScreenplayElementType.shot => Icons.videocam_outlined,
  ScreenplayElementType.lyrics => Icons.music_note,
  ScreenplayElementType.note => Icons.sticky_note_2_outlined,
};

class InteractiveFictionEditor extends StatelessWidget {
  const InteractiveFictionEditor({super.key, required this.controller});
  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final project = controller.project!;
    final ir = project.interactiveFiction;
    final node = controller.selectedIfNode ?? ir.nodes.firstOrNull;
    final issues = _analyse(ir);
    return Column(
      children: [
        Material(
          color: const Color(0xFFFBFAF6),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Sōhōkō-sei · Story / Choice'),
              ),
              TextButton.icon(
                onPressed: () => _variables(context, controller),
                icon: const Icon(Icons.data_object),
                label: const Text('Variables'),
              ),
              TextButton.icon(
                onPressed: () => _play(context, ir),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play/Test'),
              ),
              IconButton(
                tooltip: 'Add passage',
                onPressed: controller.addIfNode,
                icon: const Icon(Icons.add_box_outlined),
              ),
            ],
          ),
        ),
        if (issues.isNotEmpty)
          MaterialBanner(
            content: Text(issues.join(' · ')),
            leading: const Icon(Icons.warning_amber),
            actions: [
              TextButton(onPressed: () {}, child: const Text('GRAPH CHECK')),
            ],
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final graph = _IfGraph(
                ir: ir,
                selected: node,
                onSelect: controller.selectIfNode,
              );
              final editor = node == null
                  ? const Center(child: Text('Add a passage to begin.'))
                  : _IfNodeEditor(controller: controller, node: node);
              if (constraints.maxWidth < 800) {
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Passage'),
                          Tab(text: 'Graph'),
                        ],
                      ),
                      Expanded(child: TabBarView(children: [editor, graph])),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(flex: 5, child: graph),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 4, child: editor),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _IfNodeEditor extends StatelessWidget {
  const _IfNodeEditor({required this.controller, required this.node});
  final ProjectController controller;
  final IfNode node;
  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey(node.id),
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      80 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    children: [
      TextFormField(
        initialValue: node.title,
        decoration: const InputDecoration(labelText: 'Passage title'),
        onChanged: (value) => controller.updateIfNode(node, title: value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Start passage'),
        value: controller.project!.interactiveFiction.startNodeId == node.id,
        onChanged: (value) {
          if (value) controller.setIfStart(node);
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ending passage'),
        value: node.isEnding,
        onChanged: (value) => controller.updateIfNode(node, ending: value),
      ),
      TextFormField(
        initialValue: node.content,
        minLines: 8,
        maxLines: null,
        decoration: const InputDecoration(
          labelText: 'Passage prose (CommonMark)',
          alignLabelWithHint: true,
        ),
        onChanged: (value) => controller.updateIfNode(node, content: value),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Text('Choices', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          TextButton.icon(
            onPressed: () => controller.addIfChoice(node),
            icon: const Icon(Icons.add_link),
            label: const Text('Add choice'),
          ),
        ],
      ),
      for (final choice in node.choices)
        _IfChoiceEditor(controller: controller, node: node, choice: choice),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            'Assignments / effects',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Add effect',
            onPressed: () => controller.addIfEffect(node),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      for (final effect in node.effects)
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: effect.variable,
                decoration: const InputDecoration(labelText: 'Variable'),
                onChanged: (value) {
                  effect.variable = value;
                  controller.changed();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: effect.expression,
                decoration: const InputDecoration(labelText: 'Expression'),
                onChanged: (value) {
                  effect.expression = value;
                  controller.changed();
                },
              ),
            ),
          ],
        ),
    ],
  );
}

class _IfChoiceEditor extends StatelessWidget {
  const _IfChoiceEditor({
    required this.controller,
    required this.node,
    required this.choice,
  });
  final ProjectController controller;
  final IfNode node;
  final IfChoice choice;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          TextFormField(
            initialValue: choice.label,
            decoration: const InputDecoration(labelText: 'Choice text'),
            onChanged: (value) =>
                controller.updateIfChoice(choice, label: value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: choice.targetNodeId,
            decoration: const InputDecoration(labelText: 'Target passage'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Unlinked'),
              ),
              ...controller.project!.interactiveFiction.nodes.map(
                (target) => DropdownMenuItem<String?>(
                  value: target.id,
                  child: Text(target.title),
                ),
              ),
            ],
            onChanged: (value) =>
                controller.updateIfChoice(choice, targetNodeId: value ?? ''),
          ),
          TextFormField(
            initialValue: choice.condition,
            decoration: const InputDecoration(
              labelText: 'Condition (optional)',
            ),
            onChanged: (value) =>
                controller.updateIfChoice(choice, condition: value),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => controller.deleteIfChoice(node, choice),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _IfGraph extends StatelessWidget {
  const _IfGraph({
    required this.ir,
    required this.selected,
    required this.onSelect,
  });
  final SohoIr ir;
  final IfNode? selected;
  final ValueChanged<IfNode> onSelect;
  @override
  Widget build(BuildContext context) => InteractiveViewer(
    constrained: false,
    boundaryMargin: const EdgeInsets.all(300),
    minScale: .3,
    maxScale: 2,
    child: SizedBox(
      width: 1200,
      height: 800,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GraphPainter(ir))),
          for (var index = 0; index < ir.nodes.length; index++)
            Positioned(
              left: ir.nodes[index].x == 0
                  ? 60 + (index % 4) * 250
                  : ir.nodes[index].x,
              top: ir.nodes[index].y == 0
                  ? 60 + (index ~/ 4) * 170
                  : ir.nodes[index].y,
              child: SizedBox(
                width: 200,
                child: Card(
                  color: selected == ir.nodes[index]
                      ? const Color(0xFFDCEFE5)
                      : null,
                  child: InkWell(
                    onTap: () => onSelect(ir.nodes[index]),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ir.nodes[index].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ir.nodes[index].id == ir.startNodeId
                                ? 'START'
                                : ir.nodes[index].isEnding
                                ? 'ENDING'
                                : '${ir.nodes[index].choices.length} choice(s)',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.ir);
  final SohoIr ir;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4F7F68)
      ..strokeWidth = 2;
    Offset position(IfNode node) {
      final index = ir.nodes.indexOf(node);
      return Offset(
        node.x == 0 ? 160 + (index % 4) * 250 : node.x + 100,
        node.y == 0 ? 100 + (index ~/ 4) * 170 : node.y + 40,
      );
    }

    for (final node in ir.nodes) {
      for (final choice in node.choices) {
        final target = ir.nodes
            .where((item) => item.id == choice.targetNodeId)
            .firstOrNull;
        if (target != null) {
          canvas.drawLine(position(node), position(target), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}

List<String> _analyse(SohoIr ir) {
  final ids = ir.nodes.map((node) => node.id).toSet();
  final dead = ir.nodes
      .expand((node) => node.choices)
      .where(
        (choice) =>
            choice.targetNodeId == null || !ids.contains(choice.targetNodeId),
      )
      .length;
  final reached = <String>{};
  void visit(String? id) {
    if (id == null || !reached.add(id)) return;
    final node = ir.nodes.where((item) => item.id == id).firstOrNull;
    if (node != null) {
      for (final choice in node.choices) {
        visit(choice.targetNodeId);
      }
    }
  }

  visit(ir.startNodeId);
  final unreachable = ids.difference(reached).length;
  return [
    if (ir.startNodeId == null || !ids.contains(ir.startNodeId))
      'No valid start passage',
    if (dead > 0) '$dead dead link(s)',
    if (unreachable > 0) '$unreachable unreachable passage(s)',
  ];
}

Future<void> _variables(
  BuildContext context,
  ProjectController controller,
) async {
  final name = TextEditingController(),
      value = TextEditingController(text: '0');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('Variables'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final variable
              in controller.project!.interactiveFiction.variables.entries)
            ListTile(title: Text(variable.key), trailing: Text(variable.value)),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'New variable'),
          ),
          TextField(
            controller: value,
            decoration: const InputDecoration(labelText: 'Initial value'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            controller.setIfVariable(name.text, value.text);
            Navigator.pop(dialogContext);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
  name.dispose();
  value.dispose();
}

Future<void> _play(BuildContext context, SohoIr ir) async {
  var current = ir.nodes.where((node) => node.id == ir.startNodeId).firstOrNull;
  final variables = <String, Object?>{
    for (final entry in ir.variables.entries) entry.key: _literal(entry.value),
  };
  void enter(String? targetId) {
    current = ir.nodes.where((node) => node.id == targetId).firstOrNull;
    for (final effect in current?.effects ?? const <IfEffect>[]) {
      if (effect.variable.trim().isNotEmpty) {
        variables[effect.variable.trim()] = _expression(
          effect.expression,
          variables,
        );
      }
    }
  }

  if (current != null) enter(current!.id);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(current?.title ?? 'Cannot start'),
        content: current == null
            ? const Text('Choose a valid start passage.')
            : CommonMarkView(data: current!.content),
        actions: [
          if (current != null)
            for (final choice in current!.choices.where(
              (choice) => _condition(choice.condition, variables),
            ))
              TextButton(
                onPressed: choice.targetNodeId == null
                    ? null
                    : () => setState(() => enter(choice.targetNodeId)),
                child: Text(choice.label),
              ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Stop'),
          ),
        ],
      ),
    ),
  );
}

Object _literal(String source) {
  final value = source.trim();
  if (value == 'true') return true;
  if (value == 'false') return false;
  return num.tryParse(value) ??
      value.replaceAll(RegExp(r'''^["']|["']$'''), '');
}

Object? _expression(String source, Map<String, Object?> variables) {
  final value = source.trim();
  final addition = RegExp(r'^([A-Za-z_]\w*)\s*\+\s*(-?\d+(?:\.\d+)?)$')
      .firstMatch(value);
  if (addition != null) {
    final left = variables[addition.group(1)] as num? ?? 0;
    return left + num.parse(addition.group(2)!);
  }
  return variables.containsKey(value) ? variables[value] : _literal(value);
}

bool _condition(String? source, Map<String, Object?> variables) {
  final value = source?.trim() ?? '';
  if (value.isEmpty) return true;
  if (value.startsWith('!')) {
    return !_condition(value.substring(1), variables);
  }
  final comparison = RegExp(r'^([A-Za-z_]\w*)\s*(==|!=|>=|<=|>|<)\s*(.+)$')
      .firstMatch(value);
  if (comparison != null) {
    final left = variables[comparison.group(1)];
    final right = _literal(comparison.group(3)!);
    return switch (comparison.group(2)) {
      '==' => left == right,
      '!=' => left != right,
      '>' => left is num && right is num && left > right,
      '<' => left is num && right is num && left < right,
      '>=' => left is num && right is num && left >= right,
      '<=' => left is num && right is num && left <= right,
      _ => false,
    };
  }
  final result = variables[value];
  return result == true ||
      (result is num && result != 0) ||
      (result is String && result.isNotEmpty);
}
