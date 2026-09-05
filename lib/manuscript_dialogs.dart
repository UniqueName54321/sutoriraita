import 'package:flutter/material.dart';

import 'models.dart';
import 'project_controller.dart';

Future<void> showSceneMetadata(
  BuildContext context,
  ProjectController controller,
  StoryScene scene,
) => showDialog(
  context: context,
  builder: (_) => _MetadataDialog(controller: controller, scene: scene),
);

class _MetadataDialog extends StatefulWidget {
  const _MetadataDialog({required this.controller, required this.scene});
  final ProjectController controller;
  final StoryScene scene;
  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  late final fields = [
    TextEditingController(text: widget.scene.pov),
    TextEditingController(text: widget.scene.location),
    TextEditingController(text: widget.scene.storyDate),
    TextEditingController(text: widget.scene.status),
  ];
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Scene details: ${widget.scene.title}'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: fields[i],
                  decoration: InputDecoration(
                    labelText: [
                      'POV',
                      'Location',
                      'Story date / time',
                      'Status',
                    ][i],
                    hintText: i == 3 ? 'Draft, Revised, Final…' : null,
                  ),
                ),
              ),
            const Text(
              'Dates may use your fictional calendar. These details stay with the scene when it moves or is copied.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          widget.controller.setSceneMetadata(
            widget.scene,
            pov: fields[0].text,
            location: fields[1].text,
            date: fields[2].text,
            status: fields[3].text,
          );
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

Future<void> showMoveScenes(
  BuildContext context,
  ProjectController controller,
  List<StoryScene> scenes,
) => showDialog(
  context: context,
  builder: (_) => _MoveScenesDialog(controller: controller, scenes: scenes),
);

class _MoveScenesDialog extends StatefulWidget {
  const _MoveScenesDialog({required this.controller, required this.scenes});
  final ProjectController controller;
  final List<StoryScene> scenes;
  @override
  State<_MoveScenesDialog> createState() => _MoveScenesDialogState();
}

class _MoveScenesDialogState extends State<_MoveScenesDialog> {
  late StorySection chapter = widget.controller.project!.sections.first;
  int position = 0;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Move ${widget.scenes.length} scene(s)'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<StorySection>(
              initialValue: chapter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Destination chapter',
              ),
              items: widget.controller.project!.sections
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                chapter = value!;
                position = 0;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(chapter.id),
              initialValue: position,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Position'),
              items: [
                for (var i = 0; i <= chapter.scenes.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      i == chapter.scenes.length
                          ? 'End of chapter'
                          : 'Before ${chapter.scenes[i].title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => position = value!),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scenes keep their manuscript order, text and metadata.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          widget.controller.moveScenes(widget.scenes, chapter, position);
          Navigator.pop(context);
        },
        child: const Text('Move'),
      ),
    ],
  );
}

Future<void> confirmMergeScenes(
  BuildContext context,
  ProjectController controller,
  List<StoryScene> scenes,
) async {
  if (scenes.length < 2) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Merge ${scenes.length} scenes?'),
      content: const Text(
        'Combine their text in manuscript order. Keep the first scene’s title and metadata, redirect internal scene links to it, and put the other originals in Trash. You can undo the merge.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Merge'),
        ),
      ],
    ),
  );
  if (yes == true) controller.mergeScenes(scenes);
}

Future<void> showManuscriptSearch(
  BuildContext context,
  ProjectController controller,
) => showDialog(
  context: context,
  builder: (_) => _SearchDialog(controller: controller),
);

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.controller});
  final ProjectController controller;
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final query = TextEditingController(), replacement = TextEditingController();
  bool matchCase = false, wholeWord = false, includeEncyclopedia = true;
  String? notice;
  @override
  void dispose() {
    query.dispose();
    replacement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final hits = c.searchManuscript(
      query.text,
      matchCase: matchCase,
      wholeWord: wholeWord,
    );
    final entries = includeEncyclopedia
        ? c.searchEncyclopedia(
            query.text,
            matchCase: matchCase,
            wholeWord: wholeWord,
          )
        : <({EncyclopediaEntry entry, int start, int end})>[];
    final count = hits.length + entries.length;
    return AlertDialog(
      title: const Text('Project search / replace'),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .55,
        child: ListView(
          children: [
            TextField(
              controller: query,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Find literal text'),
              onChanged: (_) => setState(() => notice = null),
            ),
            TextField(
              controller: replacement,
              decoration: const InputDecoration(
                labelText: 'Replace with (empty removes matches)',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Match case'),
                  selected: matchCase,
                  onSelected: (v) => setState(() {
                    matchCase = v;
                    notice = null;
                  }),
                ),
                FilterChip(
                  label: const Text('Whole word'),
                  selected: wholeWord,
                  onSelected: (v) => setState(() {
                    wholeWord = v;
                    notice = null;
                  }),
                ),
                FilterChip(
                  label: const Text('Include encyclopedia'),
                  selected: includeEncyclopedia,
                  onSelected: (v) => setState(() {
                    includeEncyclopedia = v;
                    notice = null;
                  }),
                ),
              ],
            ),
            Text(
              notice ??
                  '$count match(es). Searches scene and entry body text. Trash is excluded.',
            ),
            for (final hit in hits.take(200))
              ListTile(
                title: Text('${hit.chapter.title} / ${hit.scene.title}'),
                subtitle: Text(hit.excerpt),
                onTap: () {
                  c.selectMention(hit);
                  Navigator.pop(context);
                },
              ),
            for (final hit in entries.take(200))
              ListTile(
                title: Text('Encyclopedia / ${hit.entry.title}'),
                subtitle: Text(
                  hit.entry.content.substring(
                    (hit.start - 35).clamp(0, hit.entry.content.length),
                    (hit.end + 55).clamp(0, hit.entry.content.length),
                  ),
                ),
                onTap: () {
                  c.selectEntry(hit.entry);
                  Navigator.pop(context);
                },
              ),
            if (hits.length > 200 || entries.length > 200)
              const Text(
                'Showing the first 200 matches per area. Replace all applies to every match.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: count == 0
              ? null
              : () {
                  final changed = c.replaceProjectText(
                    query.text,
                    replacement.text,
                    matchCase: matchCase,
                    wholeWord: wholeWord,
                    includeEncyclopedia: includeEncyclopedia,
                  );
                  setState(
                    () => notice =
                        'Replaced $changed match(es). Undo is available in the project menu.',
                  );
                },
          child: Text('Replace all $count matches'),
        ),
      ],
    );
  }
}

Future<void> showManuscriptTrash(
  BuildContext context,
  ProjectController controller,
) => showDialog(
  context: context,
  builder: (_) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => AlertDialog(
      title: const Text('Trash'),
      content: SizedBox(
        width: 550,
        height: MediaQuery.sizeOf(context).height * .5,
        child: controller.project!.trash.isEmpty
            ? const Center(child: Text('Trash is empty.'))
            : ListView(
                children: [
                  for (final item in controller.project!.trash.reversed)
                    ListTile(
                      title: Text(item['title'] as String),
                      subtitle: Text('${item['kind']} · ${item['deletedAt']}'),
                      trailing: TextButton(
                        onPressed: () {
                          try {
                            controller.restoreTrash(item);
                          } catch (e) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                        child: const Text('Restore'),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  ),
);

Future<void> showEntryBacklinks(
  BuildContext context,
  ProjectController controller,
  EncyclopediaEntry entry,
) => showDialog(
  context: context,
  builder: (context) {
    final hits = controller.backlinks(entry);
    return AlertDialog(
      title: Text('Where is ${entry.title} mentioned?'),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .5,
        child: hits.isEmpty
            ? const Center(
                child: Text(
                  'No mentions in active manuscript scenes. Add aliases to include alternate names.',
                ),
              )
            : ListView(
                children: [
                  for (final hit in hits)
                    ListTile(
                      title: Text('${hit.chapter.title} / ${hit.scene.title}'),
                      subtitle: Text(hit.excerpt),
                      onTap: () {
                        controller.selectMention(hit);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  },
);

Future<void> showEntryAliases(
  BuildContext context,
  ProjectController controller,
  EncyclopediaEntry entry,
) => showDialog(
  context: context,
  builder: (_) => _AliasesDialog(controller: controller, entry: entry),
);

class _AliasesDialog extends StatefulWidget {
  const _AliasesDialog({required this.controller, required this.entry});
  final ProjectController controller;
  final EncyclopediaEntry entry;
  @override
  State<_AliasesDialog> createState() => _AliasesDialogState();
}

class _AliasesDialogState extends State<_AliasesDialog> {
  late final text = TextEditingController(
    text: widget.entry.aliases.join('\n'),
  );
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Aliases for ${widget.entry.title}'),
    content: SizedBox(
      width: 440,
      child: TextField(
        controller: text,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: 'One alternate name per line',
          helperText: 'Used by backlinks and encyclopedia discovery.',
          errorText: error,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          try {
            widget.controller.setAliases(widget.entry, text.text.split('\n'));
            Navigator.pop(context);
          } catch (e) {
            setState(() => error = '$e');
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
