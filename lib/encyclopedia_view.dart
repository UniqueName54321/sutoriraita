import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commonmark_view.dart';
import 'gemmell.dart';
import 'genre_packs.dart';
import 'models.dart';
import 'project_controller.dart';

class EncyclopediaSidebar extends StatelessWidget {
  const EncyclopediaSidebar({
    super.key,
    required this.controller,
    this.onSelected,
  });
  final ProjectController controller;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = [...controller.project!.encyclopedia]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final suggestions = controller.entitySuggestions.take(8).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ENCYCLOPEDIA',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.3,
                  color: const Color(0xFF777368),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _createEntry(context, controller),
              tooltip: 'New entry',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 10),
            child: Text(
              'No entries yet. Add one, or accept a suggestion below.',
            ),
          ),
        for (final type in EncyclopediaType.values)
          if (entries.any((entry) => entry.type == type)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 5),
              child: Text(
                type.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: const Color(0xFF878278),
                ),
              ),
            ),
            for (final entry in entries.where((entry) => entry.type == type))
              ListTile(
                dense: true,
                selected: controller.selectedEntry == entry,
                selectedTileColor: const Color(0xFFDCE6DE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(_iconFor(type), size: 18),
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  controller.selectEntry(entry);
                  onSelected?.call();
                },
              ),
          ],
        if (suggestions.isNotEmpty) ...[
          const Divider(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'SUGGESTED FROM YOUR MANUSCRIPT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 10,
                letterSpacing: 1.1,
                color: const Color(0xFF777368),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 8),
            child: Text(
              'Deterministic suggestions based on repeated names. Nothing is sent anywhere.',
              style: TextStyle(fontSize: 12, color: Color(0xFF777368)),
            ),
          ),
          for (final suggestion in suggestions)
            ListTile(
              dense: true,
              leading: Icon(
                _iconFor(suggestion.type),
                size: 17,
                color: const Color(0xFF668071),
              ),
              title: Text(suggestion.title),
              subtitle: Text(
                '${suggestion.type.label} · ${suggestion.mentions} mentions',
              ),
              trailing: const Icon(Icons.add_circle_outline, size: 18),
              onTap: () {
                controller.addEntry(
                  title: suggestion.title,
                  type: suggestion.type,
                );
                onSelected?.call();
              },
            ),
        ],
      ],
    );
  }
}

class EncyclopediaEditor extends StatefulWidget {
  const EncyclopediaEditor({super.key, required this.controller});
  final ProjectController controller;
  @override
  State<EncyclopediaEditor> createState() => _EncyclopediaEditorState();
}

class _EncyclopediaEditorState extends State<EncyclopediaEditor> {
  late final TextEditingController textController;
  String? entryId;
  bool preview = true;
  GemmellSettings gemmell = GemmellSettings();

  @override
  void initState() {
    super.initState();
    _load();
    _reloadGemmell();
  }

  void _reloadGemmell() {
    GemmellSettings.load().then((value) {
      if (mounted) setState(() => gemmell = value);
    });
  }

  void _load() {
    entryId = widget.controller.selectedEntry?.id;
    textController = TextEditingController(
      text: widget.controller.selectedEntry?.content ?? '',
    )..addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant EncyclopediaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reloadGemmell();
    final entry = widget.controller.selectedEntry;
    if (entry?.id != entryId) {
      entryId = entry?.id;
      textController.value = TextEditingValue(
        text: entry?.content ?? '',
        selection: TextSelection.collapsed(offset: entry?.content.length ?? 0),
      );
    }
  }

  void _changed() => widget.controller.updateEntryContent(textController.text);

  Future<void> _generateEntryBase(
    EncyclopediaEntry entry, {
    required bool replace,
  }) async {
    if (!replace && textController.text.trim().isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Entry already has content'),
          content: const Text(
            'Starter generation will not overwrite an existing entry. Use “Replace with generated base” if you intentionally want a fresh base.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          replace
              ? 'Replace entry with a generated base?'
              : 'Generate entry base?',
        ),
        content: Text(
          replace
              ? 'This replaces the current entry using its structured facts. Generated text is only a starting base—not a final entry—and should be reviewed and rewritten. The normal project recovery copy can restore the previous saved version.'
              : 'This creates a starter entry from the structured facts. Generated text is only a base—not a final entry—and should be reviewed, expanded, and rewritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(replace ? 'Replace with base' : 'Generate base'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final generated = GenrePacks.generateEntryBase(
      widget.controller.project!,
      entry,
    );
    textController.value = TextEditingValue(
      text: generated,
      selection: TextSelection.collapsed(offset: generated.length),
    );
    setState(() => preview = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Generated a starter base. Review and rewrite it before treating it as final.',
        ),
      ),
    );
  }

  Future<void> _showGemmellTools(EncyclopediaEntry entry) async {
    final tools = GemmellTool.values
        .where((tool) => tool.encyclopediaOnly)
        .toList();
    final tool = await showDialog<GemmellTool>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 10, 12),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF668071)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${gemmell.name} · Encyclopedia tools',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${entry.type.label}: ${entry.title}',
                            style: const TextStyle(color: Color(0xFF777368)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tools.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tool = tools[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: Text(tool.label),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tool.instruction),
                              const SizedBox(height: 5),
                              Text(
                                tool.example,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF777368),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => Navigator.pop(dialogContext, tool),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (tool == null) return;
    gemmell = await GemmellSettings.load();
    if (!gemmell.enabled) return;
    final project = widget.controller.project!;
    final encyclopediaContext = gemmellEncyclopediaContext(project);
    final schemaContext = tool == GemmellTool.encyclopediaBodyToFacts
        ? '\n\n--- AVAILABLE STRUCTURED FIELDS FOR CURRENT ENTRY ---\n${GenrePacks.fieldsFor(project, entry).map((field) => '${field.key}: ${field.label}').join('\n')}\n--- END AVAILABLE STRUCTURED FIELDS ---'
        : '';
    final prompt = gemmell.prompt(
      tool: tool,
      project: project.title,
      scene: entry.title,
      text: textController.text,
      encyclopedia: '$encyclopediaContext$schemaContext',
      subjectKind: '${entry.type.label} entry',
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${gemmell.name}: ${tool.label} prompt copied.'),
        ),
      );
    }
  }

  Future<void> _addCustomField(EncyclopediaEntry entry) async {
    var label = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add custom field'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Field name'),
          onChanged: (value) => label = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, label),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null) widget.controller.addCustomEntryField(entry, result);
  }

  Future<void> _addRelation(EncyclopediaEntry entry) async {
    final project = widget.controller.project!;
    final others = project.encyclopedia.where((item) => item != entry).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create another encyclopedia entry first.'),
        ),
      );
      return;
    }
    EncyclopediaEntry target = others.first;
    RelationTypeDefinition? relationType;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final choices = GenrePacks.relationsFor(
            project,
            entry.type,
            target.type,
          );
          if (!choices.contains(relationType)) {
            relationType = choices.firstOrNull;
          }
          return AlertDialog(
            title: const Text('Add relation'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<EncyclopediaEntry>(
                    initialValue: target,
                    decoration: const InputDecoration(
                      labelText: 'Related entry',
                    ),
                    items: others
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      target = value ?? target;
                      relationType = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RelationTypeDefinition>(
                    key: ValueKey('${target.id}:${relationType?.id}'),
                    initialValue: relationType,
                    decoration: const InputDecoration(
                      labelText: 'Relation type',
                    ),
                    items: choices
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type.kind == RelationKind.inversePair
                                  ? '${type.label} ↔ ${type.inverseLabel}'
                                  : type.label,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => relationType = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: relationType == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    if (result == true && relationType != null) {
      widget.controller.addRelation(
        from: entry,
        to: target,
        type: relationType!,
      );
    }
  }

  @override
  void dispose() {
    textController.removeListener(_changed);
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.controller.selectedEntry;
    if (entry == null) {
      return const Center(
        child: Text('Select or create an encyclopedia entry.'),
      );
    }
    final project = widget.controller.project!;
    final definitions = GenrePacks.fieldsFor(project, entry);
    final subtypes = GenrePacks.subtypesFor(project, entry.type);
    final relations = project.relations
        .where(
          (relation) =>
              relation.fromEntryId == entry.id ||
              relation.toEntryId == entry.id,
        )
        .toList();
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFFBFAF6),
            border: Border(bottom: BorderSide(color: Color(0xFFE7E3D9))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              return Row(
                children: [
                  Icon(_iconFor(entry.type), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (gemmell.enabled)
                    IconButton(
                      tooltip: '${gemmell.name} encyclopedia tools',
                      onPressed: () => _showGemmellTools(entry),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 19),
                    ),
                  if (compact) ...[
                    IconButton(
                      tooltip: 'Write',
                      isSelected: !preview,
                      onPressed: () => setState(() => preview = false),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                    ),
                    IconButton(
                      tooltip: 'View',
                      isSelected: preview,
                      onPressed: () => setState(() => preview = true),
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                    ),
                  ] else
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.edit_outlined, size: 17),
                          label: Text('Write'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.visibility_outlined, size: 17),
                          label: Text('View'),
                        ),
                      ],
                      selected: {preview},
                      onSelectionChanged: (value) =>
                          setState(() => preview = value.first),
                      showSelectedIcon: false,
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await _entryDialog(
                          context,
                          entry: entry,
                        );
                        if (result != null) {
                          widget.controller.updateEntry(
                            entry,
                            title: result.$1,
                            type: result.$2,
                          );
                        }
                      }
                      if (value == 'delete' && context.mounted) {
                        widget.controller.deleteEntry(entry);
                      }
                      if (value == 'generate-base' && context.mounted) {
                        await _generateEntryBase(entry, replace: false);
                      }
                      if (value == 'replace-base' && context.mounted) {
                        await _generateEntryBase(entry, replace: true);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit title and type'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'generate-base',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.auto_fix_high_outlined),
                          title: Text('Generate starter from facts'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'replace-base',
                        enabled: textController.text.trim().isNotEmpty,
                        child: const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.restart_alt),
                          title: Text('Replace with generated base'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete entry'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
              MediaQuery.sizeOf(context).width < 700 ? 20 : 34,
              MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
              100,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.type.label.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: const Color(0xFF817C72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 28),
                    if (subtypes.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: entry.subtype,
                        decoration: const InputDecoration(labelText: 'Subtype'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No subtype'),
                          ),
                          ...subtypes.map(
                            (value) => DropdownMenuItem<String?>(
                              value: value,
                              child: Text(
                                GenrePacks.subtypeLabel(project, value),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            widget.controller.setEntrySubtype(entry, value),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Structured facts',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 17),
                                ),
                                TextButton.icon(
                                  onPressed: () => _addCustomField(entry),
                                  icon: const Icon(Icons.add, size: 17),
                                  label: const Text('Custom field'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (final definition in definitions) ...[
                              TextFormField(
                                initialValue:
                                    entry.fields[definition.key] ?? '',
                                decoration: InputDecoration(
                                  labelText: definition.label,
                                ),
                                onChanged: (value) =>
                                    widget.controller.setEntryField(
                                      entry,
                                      definition.key,
                                      value,
                                    ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            for (final field in entry.fields.entries.where(
                              (field) => field.key.startsWith('custom:'),
                            )) ...[
                              TextFormField(
                                initialValue: field.value,
                                decoration: InputDecoration(
                                  labelText: field.key.substring(7),
                                ),
                                onChanged: (value) => widget.controller
                                    .setEntryField(entry, field.key, value),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Relations',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 17),
                                ),
                                TextButton.icon(
                                  onPressed: () => _addRelation(entry),
                                  icon: const Icon(Icons.add_link, size: 17),
                                  label: const Text('Add relation'),
                                ),
                              ],
                            ),
                            if (relations.isEmpty)
                              const Text('No relations yet.'),
                            for (final relation in relations)
                              _RelationTile(
                                relation: relation,
                                current: entry,
                                project: project,
                                controller: widget.controller,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (preview)
                      CommonMarkView(data: textController.text)
                    else
                      TextField(
                        controller: textController,
                        minLines: 18,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Describe this entry in CommonMark…',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RelationTile extends StatelessWidget {
  const _RelationTile({
    required this.relation,
    required this.current,
    required this.project,
    required this.controller,
  });
  final EntryRelation relation;
  final EncyclopediaEntry current;
  final StoryProject project;
  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final from = project.encyclopedia
        .where((entry) => entry.id == relation.fromEntryId)
        .firstOrNull;
    final to = project.encyclopedia
        .where((entry) => entry.id == relation.toEntryId)
        .firstOrNull;
    if (from == null || to == null) return const SizedBox.shrink();
    final definitions = [
      ...GenrePacks.baseRelations,
      for (final pack in GenrePacks.active(project)) ...pack.relations,
    ];
    final type = definitions
        .where((definition) => definition.id == relation.relationTypeId)
        .firstOrNull;
    final reverse = current.id == to.id;
    final other = reverse ? from : to;
    final label = type == null
        ? relation.relationTypeId
        : reverse && type.kind == RelationKind.inversePair
        ? type.inverseLabel ?? type.label
        : type.label;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('$label ${other.title}'),
      subtitle: Text(type?.kind.name ?? 'custom'),
      trailing: IconButton(
        tooltip: 'Delete relation',
        onPressed: () => controller.deleteRelation(relation),
        icon: const Icon(Icons.delete_outline, size: 18),
      ),
      children: [
        for (final field in type?.fields ?? const <String>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              initialValue: relation.fields[field] ?? '',
              decoration: InputDecoration(labelText: field),
              onChanged: (value) =>
                  controller.setRelationField(relation, field, value),
            ),
          ),
      ],
    );
  }
}

Future<void> _createEntry(
  BuildContext context,
  ProjectController controller,
) async {
  final result = await _entryDialog(context);
  if (result != null) controller.addEntry(title: result.$1, type: result.$2);
}

Future<(String, EncyclopediaType)?> _entryDialog(
  BuildContext context, {
  EncyclopediaEntry? entry,
}) => showDialog<(String, EncyclopediaType)>(
  context: context,
  builder: (_) => _EncyclopediaEntryDialog(entry: entry),
);

class _EncyclopediaEntryDialog extends StatefulWidget {
  const _EncyclopediaEntryDialog({this.entry});
  final EncyclopediaEntry? entry;

  @override
  State<_EncyclopediaEntryDialog> createState() =>
      _EncyclopediaEntryDialogState();
}

class _EncyclopediaEntryDialogState extends State<_EncyclopediaEntryDialog> {
  late final TextEditingController title = TextEditingController(
    text: widget.entry?.title ?? '',
  );
  late EncyclopediaType type = widget.entry?.type ?? EncyclopediaType.character;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.entry == null
          ? 'New encyclopedia entry'
          : 'Edit encyclopedia entry',
    ),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<EncyclopediaType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: EncyclopediaType.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => type = value ?? type),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              type.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF777368)),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isNotEmpty) {
            Navigator.pop(context, (title.text.trim(), type));
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

IconData _iconFor(EncyclopediaType type) => switch (type) {
  EncyclopediaType.character => Icons.person_outline,
  EncyclopediaType.location => Icons.place_outlined,
  EncyclopediaType.group => Icons.groups_outlined,
  EncyclopediaType.object => Icons.category_outlined,
  EncyclopediaType.event => Icons.event_outlined,
  EncyclopediaType.concept => Icons.lightbulb_outline,
  EncyclopediaType.other => Icons.article_outlined,
};
