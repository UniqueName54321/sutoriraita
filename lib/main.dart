import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commonmark_view.dart';
import 'document_exporter.dart';
import 'encyclopedia_view.dart';
import 'gemmell.dart';
import 'genre_packs.dart';
import 'internal_links.dart';
import 'models.dart';
import 'mode_editors.dart';
import 'project_controller.dart';
import 'project_action_menu.dart';
import 'project_store.dart';
import 'project_documents.dart';
import 'proofreading.dart';

List<String> launchArguments = [];

void main(List<String> args) {
  launchArguments = args;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SutoriraitaApp());
}

class SutoriraitaApp extends StatelessWidget {
  const SutoriraitaApp({super.key});
  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF26251F),
        paper = Color(0xFFF8F6F0),
        green = Color(0xFF385D4B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sutōrīraitā',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          surface: paper,
          onSurface: ink,
        ),
        fontFamily: 'Georgia',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 38,
            height: 1.12,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -.7,
          ),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 17, height: 1.65),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45),
          labelLarge: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w600,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .72),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDCD8CD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDCD8CD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.store});
  final ProjectStore? store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ProjectController controller;
  Timer? _documentTimer;
  bool _openingDocument = false;
  bool _importingHammer = false;
  @override
  void initState() {
    super.initState();
    controller = ProjectController(widget.store ?? ProjectStore())
      ..addListener(_refresh);
    _restoreAndListen();
  }

  Future<void> _restoreAndListen() async {
    await controller.restore();
    if (!mounted) return;
    for (final argument in launchArguments) {
      if (!argument.startsWith('-')) await _openExternal(path: argument);
    }
    await _offerHammerImport();
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _pollDocuments();
      if (mounted) {
        _documentTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _pollDocuments(),
        );
      }
    }
  }

  Future<void> _offerHammerImport() async {
    try {
      final paths = await controller.store.discoverHammerProjects();
      if (paths.isEmpty || !mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final accept = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import your Hammer stories?'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Text(
                'Found ${paths.length} stories in Documents/HammerProjects. '
                'Import copies into Sutōrīraitā? Your Hammer files will not be changed.\n\n'
                '${paths.map((p) => p.split(Platform.pathSeparator).last).join('\n')}\n\n'
                'Skipped stories can still be imported from Import → Hammer story.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Skip these stories'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import copies'),
            ),
          ],
        ),
      );
      if (accept == null || !mounted) return;
      if (!accept) {
        await controller.store.markHammerHandled(paths);
        return;
      }
      setState(() => _importingHammer = true);
      var imported = 0;
      final failed = <String>[];
      // Keep any current project open. Importing copies is independent of its
      // autosave and must never replace unsaved work.
      for (final path in paths) {
        try {
          await controller.store.importHammerFolder(sourcePath: path);
          imported++;
        } catch (error) {
          failed.add('${path.split(Platform.pathSeparator).last}: $error');
        }
      }
      final active = controller.project;
      if (active != null) {
        await controller.store.remember(active);
      } else {
        await controller.store.forgetLast();
      }
      if (!mounted) return;
      setState(() => _importingHammer = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Imported $imported Hammer stories'),
          content: SingleChildScrollView(
            child: Text(
              failed.isEmpty
                  ? 'Your copies are available in the project list.'
                  : 'These stories could not be imported and can be retried:\n\n${failed.join('\n\n')}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _importingHammer = false);
      if (mounted) _showDocumentError(error);
    }
  }

  Future<void> _pollDocuments() async {
    if (_openingDocument || !mounted) return;
    _openingDocument = true;
    try {
      final bytes = await ProjectDocuments.channel.invokeMethod<Uint8List>(
        'nextDocument',
      );
      if (bytes != null && mounted) await _openExternal(bytes: bytes);
    } on MissingPluginException {
      // Widget tests and platforms without a native document bridge.
    } catch (error) {
      if (mounted) _showDocumentError(error);
    } finally {
      _openingDocument = false;
    }
  }

  Future<void> _openExternal({String? path, Uint8List? bytes}) async {
    try {
      await controller.saveNow();
      if (controller.saveState == SaveState.error) {
        throw StateError('Save the current project before opening another.');
      }
      final source = path != null && path.startsWith('file:')
          ? Uri.parse(path).toFilePath()
          : path;
      final project = await controller.store.openPackage(
        sourcePath: source,
        bytes: bytes,
      );
      if (mounted) controller.useProject(project);
    } catch (error) {
      if (mounted) _showDocumentError(error);
    }
  }

  void _showDocumentError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open project: $error')));
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _documentTimer?.cancel();
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => controller.loading || _importingHammer
      ? const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      : controller.project == null
      ? WelcomeScreen(controller: controller)
      : WorkspaceScreen(controller: controller);
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.controller});
  final ProjectController controller;
  Future<void> _create(BuildContext context) async {
    final result = await showDialog<(String, String, ProjectType)>(
      context: context,
      builder: (_) => const CreateProjectDialog(),
    );
    if (result == null || !context.mounted) return;
    try {
      controller.useProject(
        await controller.store.create(
          title: result.$1,
          author: result.$2,
          type: result.$3,
        ),
      );
    } on ProjectCancelled {
      // The user closed the native folder picker.
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _open(BuildContext context) async {
    try {
      controller.useProject(await controller.store.open());
    } on ProjectCancelled {
      // The user closed the native folder picker.
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _openPackage(BuildContext context) async {
    try {
      controller.useProject(await controller.store.openPackage());
    } on ProjectCancelled {
      // Native picker cancelled.
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open project: $error')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      controller.useProject(await controller.store.importMarkdownFolder());
    } on ProjectCancelled {
      // The user closed the native folder picker.
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _importNovelist(BuildContext context) async {
    try {
      controller.useProject(await controller.store.importNovelistFile());
    } on ProjectCancelled {
      // The user closed the native file picker.
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _importFountain(BuildContext context) async {
    try {
      controller.useProject(await controller.store.importFountain());
    } on ProjectCancelled {
      // The user closed the native file picker.
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _importHammer(BuildContext context) async {
    try {
      final zip = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Import Hammer story'),
          children: [
            if (!Platform.isIOS)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const ListTile(
                  title: Text('Story folder'),
                  subtitle: Text('Select the folder containing project.toml'),
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const ListTile(
                title: Text('Story ZIP'),
                subtitle: Text('A ZIP containing one Hammer story folder'),
              ),
            ),
            if (Platform.isIOS)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'On iOS, compress the Hammer story folder in Files, then select the ZIP.',
                ),
              ),
          ],
        ),
      );
      if (zip == null) return;
      controller.useProject(
        zip
            ? await controller.store.importHammerPackage()
            : await controller.store.importHammerFolder(),
      );
    } on ProjectCancelled {
      // Native folder picker dismissed.
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _openExample(BuildContext context) async {
    try {
      controller.useProject(await controller.store.createExample());
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          return Stack(
            children: [
              Positioned(
                right: -90,
                top: -130,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE9E4D4),
                  ),
                ),
              ),
              Positioned(
                left: -70,
                bottom: -180,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE4ECE6),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 28 : 72,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: _BrandMark(large: true)),
                            IconButton(
                              tooltip: 'App settings',
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    AppSettingsDialog(controller: controller),
                              ),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 54),
                        Text(
                          'A quiet place\nfor loud ideas.',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: narrow ? 44 : 68,
                                height: 1.02,
                              ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Plan in scenes. Write in Markdown. Keep every word close.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF6B685F)),
                        ),
                        const SizedBox(height: 42),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ProjectActionMenu(
                              label: 'New project',
                              icon: Icons.add_rounded,
                              primary: true,
                              entries: [
                                (
                                  label: 'Blank project',
                                  icon: Icons.note_add_outlined,
                                  onPressed: () => _create(context),
                                ),
                                (
                                  label: 'From example story',
                                  icon: Icons.menu_book_outlined,
                                  onPressed: () => _openExample(context),
                                ),
                              ],
                            ),
                            ProjectActionMenu(
                              label: 'Open',
                              icon: Icons.folder_open_outlined,
                              entries: [
                                (
                                  label: 'Packed project (.sutoriraita)',
                                  icon: Icons.file_open_outlined,
                                  onPressed: () => _openPackage(context),
                                ),
                                (
                                  label: 'Project folder',
                                  icon: Icons.folder_open_outlined,
                                  onPressed: () => _open(context),
                                ),
                              ],
                            ),
                            ProjectActionMenu(
                              label: 'Import',
                              icon: Icons.file_download_outlined,
                              entries: [
                                (
                                  label: 'Markdown folder',
                                  icon: Icons.description_outlined,
                                  onPressed: () => _import(context),
                                ),
                                (
                                  label: 'Novelist story (.nov)',
                                  icon: Icons.auto_stories_outlined,
                                  onPressed: () => _importNovelist(context),
                                ),
                                (
                                  label: 'Hammer story…',
                                  icon: Icons.folder_copy_outlined,
                                  onPressed: () => _importHammer(context),
                                ),
                                (
                                  label: 'Fountain screenplay (.fountain)',
                                  icon: Icons.movie_creation_outlined,
                                  onPressed: () => _importFountain(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 46),
                        _ProjectLibrary(controller: controller),
                        const SizedBox(height: 46),
                        const Text(
                          'VERSION 0.1.0  •  PRE-ALPHA',
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 11,
                            letterSpacing: 1.4,
                            color: Color(0xFF8B877B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ProjectLibrary extends StatefulWidget {
  const _ProjectLibrary({required this.controller});
  final ProjectController controller;
  @override
  State<_ProjectLibrary> createState() => _ProjectLibraryState();
}

class _ProjectLibraryState extends State<_ProjectLibrary> {
  late Future<List<ProjectSummary>> projects = widget.controller.store
      .discoverProjects();
  final search = TextEditingController();
  String sort = 'updated';
  bool showArchived = false;

  void _refresh() => setState(() {
    projects = showArchived
        ? widget.controller.store.discoverArchivedProjects()
        : widget.controller.store.discoverProjects();
  });

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _projectAction(ProjectSummary project, String action) async {
    try {
      if (action == 'backup') {
        await widget.controller.store.backupProject(project.path);
      } else if (action == 'archive') {
        if (!await _confirm(context, 'Archive “${project.title}”?')) return;
        await widget.controller.store.archiveProject(project.path);
      } else if (action == 'delete') {
        if (!await _confirm(
          context,
          'Permanently delete “${project.title}”? This cannot be undone.',
        )) {
          return;
        }
        await widget.controller.store.permanentlyDeleteProject(project.path);
      }
      _refresh();
    } on ProjectCancelled {
      // The user closed the backup picker.
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _bulkAction(bool delete) async {
    final phrase = delete ? 'DELETE ALL STORIES' : 'ARCHIVE ALL STORIES';
    if (!await _strongConfirmation(context, phrase)) return;
    if (delete) {
      await widget.controller.store.permanentlyDeleteAllProjects();
    } else {
      await widget.controller.store.archiveAllProjects();
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ProjectSummary>>(
    future: projects,
    builder: (context, snapshot) {
      final query = search.text.trim().toLowerCase();
      final items = (snapshot.data ?? const <ProjectSummary>[])
          .where(
            (project) =>
                query.isEmpty ||
                project.title.toLowerCase().contains(query) ||
                project.author.toLowerCase().contains(query),
          )
          .toList();
      items.sort(
        (a, b) => switch (sort) {
          'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          'words' => b.wordCount.compareTo(a.wordCount),
          _ => b.updatedAt.compareTo(a.updatedAt),
        },
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'YOUR PROJECTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.3,
                    color: const Color(0xFF777368),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh projects',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search projects',
                    isDense: true,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: sort,
                  items: const [
                    DropdownMenuItem(
                      value: 'updated',
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(value: 'title', child: Text('Title A–Z')),
                    DropdownMenuItem(value: 'words', child: Text('Most words')),
                  ],
                  onChanged: (value) => setState(() => sort = value ?? sort),
                ),
              ),
              FilterChip(
                selected: showArchived,
                label: const Text('Archived'),
                onSelected: (value) {
                  showArchived = value;
                  _refresh();
                },
              ),
              OutlinedButton(
                onPressed: showArchived ? null : () => _bulkAction(false),
                child: const Text('Archive all'),
              ),
              TextButton(
                onPressed: () => _bulkAction(true),
                child: const Text('Delete all permanently'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(minHeight: 2)
          else if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1DDD2)),
              ),
              child: const Text(
                'No projects yet. Create one or explore Mochi to begin.',
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (project) => _ProjectCard(
                      project: project,
                      archived: showArchived,
                      onAction: (action) => _projectAction(project, action),
                      onOpen: () async {
                        try {
                          widget.controller.useProject(
                            await widget.controller.store.open(project.path),
                          );
                        } catch (error) {
                          if (context.mounted) _showError(context, error);
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
        ],
      );
    },
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onAction,
    required this.archived,
  });
  final ProjectSummary project;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  final bool archived;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 17),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Project actions',
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'backup',
                        child: Text('Backup as portable package'),
                      ),
                      if (!archived)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete permanently'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                project.author.isEmpty ? 'Unknown author' : project.author,
                style: const TextStyle(fontSize: 12, color: Color(0xFF777368)),
              ),
              const SizedBox(height: 14),
              Text(
                '${project.wordCount} words',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontSize: 11, color: const Color(0xFF668071)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.controller});
  final ProjectController controller;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  bool sidebarOpen = true;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  void _toggleSidebar(bool narrow) {
    if (narrow) {
      scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() => sidebarOpen = !sidebarOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final sidebar = ManuscriptSidebar(
      controller: widget.controller,
      onClose: narrow ? () => scaffoldKey.currentState?.closeDrawer() : null,
    );
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true):
            _NewSceneIntent(),
      },
      child: Actions(
        actions: {
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              widget.controller.saveNow();
              return null;
            },
          ),
          _NewSceneIntent: CallbackAction<_NewSceneIntent>(
            onInvoke: (_) {
              final c = widget.controller;
              final section = c.selectedScene == null
                  ? c.project!.sections.first
                  : c.sectionFor(c.selectedScene!)!;
              c.addScene(section);
              return null;
            },
          ),
        },
        child: Scaffold(
          key: scaffoldKey,
          drawer: narrow
              ? Drawer(width: 310, child: SafeArea(child: sidebar))
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (!narrow && sidebarOpen)
                  SizedBox(width: 300, child: sidebar),
                Expanded(
                  child: Column(
                    children: [
                      WorkspaceTopBar(
                        controller: widget.controller,
                        onMenu: () => _toggleSidebar(narrow),
                      ),
                      Expanded(
                        child:
                            widget.controller.area == WorkspaceArea.encyclopedia
                            ? EncyclopediaEditor(controller: widget.controller)
                            : switch (widget.controller.project!.type) {
                                ProjectType.screenplay => ScreenplayEditor(
                                  controller: widget.controller,
                                ),
                                ProjectType.interactiveFiction =>
                                  InteractiveFictionEditor(
                                    controller: widget.controller,
                                  ),
                                ProjectType.prose =>
                                  widget.controller.selectedScene == null
                                      ? const EmptyManuscript()
                                      : SceneEditor(
                                          controller: widget.controller,
                                        ),
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    super.key,
    required this.controller,
    required this.onMenu,
  });
  final ProjectController controller;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 66),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE4E0D6))),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: onMenu,
          tooltip: 'Toggle manuscript',
          icon: const Icon(Icons.segment_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            controller.project!.title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        _SaveIndicator(state: controller.saveState),
        const SizedBox(width: 5),
        PopupMenuButton<String>(
          tooltip: 'Project menu',
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) => _projectAction(context, controller, value),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'library',
              child: _MenuLabel(Icons.grid_view_outlined, 'Project list'),
            ),
            PopupMenuItem(
              value: 'settings',
              child: _MenuLabel(Icons.tune, 'Project settings'),
            ),
            PopupMenuItem(
              value: 'app-settings',
              child: _MenuLabel(Icons.settings_outlined, 'App settings'),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'document-export',
              child: _MenuLabel(
                Icons.file_download_outlined,
                'Export manuscript…',
              ),
            ),
            PopupMenuItem(
              value: 'package',
              child: _MenuLabel(
                Icons.inventory_2_outlined,
                'Export story project…',
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'close',
              child: _MenuLabel(Icons.close, 'Close project'),
            ),
          ],
        ),
      ],
    ),
  );
}

class ManuscriptSidebar extends StatelessWidget {
  const ManuscriptSidebar({super.key, required this.controller, this.onClose});
  final ProjectController controller;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < 500;
    return Material(
      color: const Color(0xFFF0EEE7),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              short ? 6 : 23,
              12,
              short ? 2 : 12,
            ),
            child: Row(
              children: [
                const Expanded(child: _BrandMark()),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close manuscript',
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, short ? 2 : 8, 12, short ? 2 : 8),
            child: SegmentedButton<WorkspaceArea>(
              segments: const [
                ButtonSegment(
                  value: WorkspaceArea.manuscript,
                  icon: Icon(Icons.description_outlined, size: 17),
                  label: Text('Story'),
                ),
                ButtonSegment(
                  value: WorkspaceArea.encyclopedia,
                  icon: Icon(Icons.menu_book_outlined, size: 17),
                  label: Text('Lore'),
                ),
              ],
              selected: {controller.area},
              showSelectedIcon: false,
              onSelectionChanged: (value) => controller.showArea(value.first),
            ),
          ),
          if (controller.area == WorkspaceArea.manuscript) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                short ? 2 : 8,
                12,
                short ? 0 : 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'MANUSCRIPT',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        color: const Color(0xFF777368),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: controller.addSection,
                    tooltip: 'New chapter',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                itemCount: controller.project!.sections.length,
                itemBuilder: (context, index) => SectionTile(
                  section: controller.project!.sections[index],
                  controller: controller,
                  onSelected: onClose,
                ),
              ),
            ),
          ] else
            Expanded(
              child: EncyclopediaSidebar(
                controller: controller,
                onSelected: onClose,
              ),
            ),
          Container(
            padding: EdgeInsets.all(short ? 8 : 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFDEDACF))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 18,
                  color: Color(0xFF777368),
                ),
                const SizedBox(width: 9),
                Text(
                  '${controller.project!.wordCount} words',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: const Color(0xFF777368)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.section,
    required this.controller,
    this.onSelected,
  });
  final StorySection section;
  final ProjectController controller;
  final VoidCallback? onSelected;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.only(left: 8, right: 2),
      childrenPadding: EdgeInsets.zero,
      leading: const Icon(Icons.keyboard_arrow_down, size: 18),
      title: Text(
        section.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      trailing: PopupMenuButton<String>(
        iconSize: 18,
        padding: EdgeInsets.zero,
        onSelected: (value) async {
          if (value == 'add') controller.addScene(section);
          if (value == 'rename') {
            final name = await _textDialog(
              context,
              'Rename chapter',
              section.title,
            );
            if (name != null) controller.renameSection(section, name);
          }
          if (value == 'delete' &&
              controller.project!.sections.length > 1 &&
              context.mounted &&
              await _confirm(
                context,
                'Delete “${section.title}” and its scenes?',
              )) {
            controller.deleteSection(section);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'add', child: Text('Add scene')),
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete chapter')),
        ],
      ),
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: section.scenes.length,
          onReorderItem: (oldIndex, newIndex) =>
              controller.reorderScene(section, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final scene = section.scenes[index],
                selected = controller.selectedScene == scene;
            return Material(
              key: ValueKey(scene.id),
              color: selected ? const Color(0xFFDCE6DE) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                dense: true,
                minLeadingWidth: 18,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 17,
                    color: Color(0xFF9C988D),
                  ),
                ),
                title: Text(
                  scene.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16),
                  padding: EdgeInsets.zero,
                  onSelected: (value) =>
                      _sceneAction(context, controller, section, scene, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'move', child: Text('Move to…')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () {
                  controller.select(scene);
                  onSelected?.call();
                },
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 27, bottom: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.addScene(section),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('New scene'),
            ),
          ),
        ),
      ],
    ),
  );
}

class SceneEditor extends StatefulWidget {
  const SceneEditor({super.key, required this.controller});
  final ProjectController controller;
  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  late final TextEditingController textController;
  final FocusNode focusNode = FocusNode();
  String? sceneId;
  bool preview = true;
  GemmellSettings gemmell = GemmellSettings();
  bool showSpelling = false;
  String previewSelection = '';
  @override
  void initState() {
    super.initState();
    sceneId = widget.controller.selectedScene?.id;
    textController = TextEditingController(
      text: widget.controller.selectedScene?.content ?? '',
    )..addListener(_changed);
    _reloadGemmell();
  }

  void _reloadGemmell() {
    GemmellSettings.load().then((value) {
      if (mounted) setState(() => gemmell = value);
    });
  }

  @override
  void didUpdateWidget(covariant SceneEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reloadGemmell();
    final scene = widget.controller.selectedScene;
    if (scene?.id != sceneId) {
      sceneId = scene?.id;
      textController.value = TextEditingValue(
        text: scene?.content ?? '',
        selection: TextSelection.collapsed(offset: scene?.content.length ?? 0),
      );
    }
  }

  void _changed() => widget.controller.updateContent(textController.text);
  void _wrap(String marker) {
    final value = textController.value, selection = value.selection;
    if (!selection.isValid) return;
    final selected = selection.textInside(value.text),
        replacement = '$marker$selected$marker';
    textController.value = value
        .replaced(selection, replacement)
        .copyWith(
          selection: TextSelection(
            baseOffset: selection.start + marker.length,
            extentOffset: selection.start + marker.length + selected.length,
          ),
        );
    focusNode.requestFocus();
  }

  void _heading() {
    final value = textController.value,
        caret = value.selection.start.clamp(0, value.text.length);
    final lineStart =
        value.text.lastIndexOf('\n', caret > 0 ? caret - 1 : 0) + 1;
    textController.value = value.replaced(
      TextSelection.collapsed(offset: lineStart),
      '## ',
    );
    focusNode.requestFocus();
  }

  void _prefixLines(String prefix) {
    final value = textController.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final start =
        value.text.lastIndexOf(
          '\n',
          selection.start > 0 ? selection.start - 1 : 0,
        ) +
        1;
    final endBreak = value.text.indexOf('\n', selection.end);
    final end = endBreak == -1 ? value.text.length : endBreak;
    final replacement = value.text
        .substring(start, end)
        .split('\n')
        .map((line) => '$prefix$line')
        .join('\n');
    textController.value = value.replaced(
      TextSelection(baseOffset: start, extentOffset: end),
      replacement,
    );
    focusNode.requestFocus();
  }

  void _insert(String text) {
    final value = textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    textController.value = value
        .replaced(selection, text)
        .copyWith(
          selection: TextSelection.collapsed(
            offset: selection.start + text.length,
          ),
        );
    focusNode.requestFocus();
  }

  Future<void> _insertSceneLink(StoryScene current) async {
    final scenes = widget.controller.project!.sections
        .expand((section) => section.scenes)
        .where((scene) => scene.id != current.id)
        .toList();
    if (scenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create another scene to link to first.')),
      );
      return;
    }
    final target = await showDialog<StoryScene>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Link to scene'),
        children: [
          for (final scene in scenes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, scene),
              child: Text(scene.title),
            ),
        ],
      ),
    );
    if (target == null) return;
    final selection = textController.selection;
    final selected = selection.isValid
        ? selection.textInside(textController.text)
        : '';
    _insert(
      InternalLinks.markdown(
        selected.trim().isEmpty ? target.title : selected,
        target.id,
      ),
    );
  }

  Future<void> _copyGemmellPrompt(
    StoryScene scene,
    GemmellTool tool, {
    String? selection,
    String transformationOptions = '',
  }) async {
    gemmell = await GemmellSettings.load();
    if (!gemmell.enabled) return;
    final project = widget.controller.project!;
    String? packagePath;
    if (tool.requiresPackage) {
      try {
        packagePath = await widget.controller.store.exportPackage(project);
      } on ProjectCancelled {
        return;
      }
    }
    final prompt = gemmell.prompt(
      tool: tool,
      project: project.title,
      scene: scene.title,
      text: textController.text,
      selection: selection,
      encyclopedia: gemmellEncyclopediaContext(project),
      transformationOptions: transformationOptions,
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: tool.requiresPackage ? 9 : 4),
          content: Text(
            tool.requiresPackage
                ? '${gemmell.name}: prompt copied. Attach “$packagePath” to your chatbot when you send it.'
                : '${gemmell.name}: ${tool.label} prompt copied.',
          ),
        ),
      );
    }
  }

  Future<void> _showSelectionTools(StoryScene scene) async {
    final selection = textController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select some manuscript text first.')),
      );
      return;
    }
    final selectedText = selection.textInside(textController.text);
    await _showSelectionToolsForText(scene, selectedText);
  }

  Future<void> _showSelectionToolsForText(
    StoryScene scene,
    String selectedText,
  ) async {
    if (selectedText.trim().isEmpty) return;
    final tool = await _showGemmellToolbox(selectionOnly: true);
    if (tool != null) {
      var options = '';
      if (tool.proseTransformation) {
        final selectedOptions = await _proseTransformationOptions(tool);
        if (selectedOptions == null) return;
        options = selectedOptions;
      }
      await _copyGemmellPrompt(
        scene,
        tool,
        selection: selectedText,
        transformationOptions: options,
      );
    }
  }

  Future<void> _showSceneTools(StoryScene scene) async {
    final tool = await _showGemmellToolbox(selectionOnly: false);
    if (tool != null) await _copyGemmellPrompt(scene, tool);
  }

  Future<GemmellTool?> _showGemmellToolbox({required bool selectionOnly}) {
    final tools = GemmellTool.values
        .where(
          (tool) =>
              tool.requiresSelection == selectionOnly &&
              !tool.encyclopediaOnly &&
              (!tool.proseTransformation || gemmell.proseTransformationEnabled),
        )
        .toList();
    return showDialog<GemmellTool>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
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
                            selectionOnly
                                ? '${gemmell.name} · Selection tools'
                                : '${gemmell.name} · Scene and story toolbox',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'Prompt Bridge · choose a tool to copy its prompt',
                            style: TextStyle(color: Color(0xFF777368)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
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
                              if (tool.proseTransformation) ...[
                                const SizedBox(height: 7),
                                const Text(
                                  'PROSE TRANSFORMATION · SELECTED PASSAGE ONLY · PROPOSAL ONLY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9A5C45),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                              Text(
                                tool.example,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF777368),
                                ),
                              ),
                              if (tool.requiresPackage) ...[
                                const SizedBox(height: 7),
                                const Text(
                                  'WHOLE STORY · exports a .sutoriraita file to attach',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF668071),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: tool.requiresPackage
                            ? const Tooltip(
                                message: 'Exports a portable project package',
                                child: Icon(Icons.inventory_2_outlined),
                              )
                            : const Icon(Icons.chevron_right),
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
  }

  Future<String?> _proseTransformationOptions(GemmellTool tool) async {
    var preserveMeaning = true;
    var readingLevel = 'General adult';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tool.label),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scope: selected passage only. The original remains in the editor; Prompt Bridge copies a request for a proposed rewrite.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Preserve meaning, change wording'),
                  value: preserveMeaning,
                  onChanged: (value) =>
                      setDialogState(() => preserveMeaning = value ?? true),
                ),
                if (tool == GemmellTool.adjustReadingLevel)
                  DropdownButtonFormField<String>(
                    initialValue: readingLevel,
                    decoration: const InputDecoration(
                      labelText: 'Target reading level',
                    ),
                    items:
                        const [
                              'Plain language',
                              'Middle grade',
                              'Young adult',
                              'General adult',
                              'Advanced adult',
                            ]
                            .map(
                              (level) => DropdownMenuItem(
                                value: level,
                                child: Text(level),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setDialogState(
                      () => readingLevel = value ?? readingLevel,
                    ),
                  ),
                if (tool == GemmellTool.expandProse) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Expansion is not automatic improvement. It may add repetition, pacing problems, or invented connective material.',
                    style: TextStyle(color: Color(0xFF9A5C45)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                '${preserveMeaning ? 'Preserve meaning, change wording.' : 'Meaning preservation option disabled; still preserve all protected story facts and choices.'}${tool == GemmellTool.adjustReadingLevel ? ' Target reading level: $readingLevel.' : ''}',
              ),
              child: const Text('Copy proposal request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commonMarkAction(String value, StoryScene scene) async {
    switch (value) {
      case 'heading':
        _heading();
      case 'quote':
        _prefixLines('> ');
      case 'list':
        _prefixLines('- ');
      case 'code':
        _wrap('`');
      case 'link':
        final selection = textController.selection;
        final label = selection.isValid
            ? selection.textInside(textController.text)
            : '';
        _insert('[${label.isEmpty ? 'link text' : label}](https://)');
      case 'scene-link':
        await _insertSceneLink(scene);
      case 'rule':
        _insert('\n\n---\n\n');
    }
  }

  Widget _commonMarkMenu(StoryScene scene) => PopupMenuButton<String>(
    enabled: !preview,
    tooltip: 'More CommonMark',
    icon: const Icon(Icons.add_box_outlined, size: 19),
    onSelected: (value) => _commonMarkAction(value, scene),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'heading', child: Text('Heading')),
      PopupMenuItem(value: 'quote', child: Text('Block quote')),
      PopupMenuItem(value: 'list', child: Text('Bulleted list')),
      PopupMenuItem(value: 'code', child: Text('Inline code')),
      PopupMenuItem(value: 'link', child: Text('Link')),
      PopupMenuItem(value: 'scene-link', child: Text('Internal scene link')),
      PopupMenuItem(value: 'rule', child: Text('Horizontal rule')),
    ],
  );

  Widget _mobileSceneToolbar(StoryScene scene, List<SpellingIssue> spelling) =>
      Row(
        children: [
          IconButton(
            onPressed: preview ? null : () => _wrap('**'),
            tooltip: 'Bold (Ctrl+B)',
            icon: const Icon(Icons.format_bold, size: 19),
          ),
          IconButton(
            onPressed: preview ? null : () => _wrap('*'),
            tooltip: 'Italic (Ctrl+I)',
            icon: const Icon(Icons.format_italic, size: 19),
          ),
          _commonMarkMenu(scene),
          const Spacer(),
          IconButton(
            isSelected: !preview,
            tooltip: 'Write',
            onPressed: () => setState(() => preview = false),
            icon: const Icon(Icons.edit_outlined, size: 19),
            selectedIcon: const Icon(Icons.edit, size: 19),
          ),
          IconButton(
            isSelected: preview,
            tooltip: 'View',
            onPressed: () => setState(() => preview = true),
            icon: const Icon(Icons.visibility_outlined, size: 19),
            selectedIcon: const Icon(Icons.visibility, size: 19),
          ),
          PopupMenuButton<String>(
            tooltip: 'Editor tools',
            icon: Badge(
              isLabelVisible: spelling.isNotEmpty,
              label: Text('${spelling.length}'),
              child: const Icon(Icons.more_vert, size: 20),
            ),
            onSelected: (value) {
              if (value == 'spelling') {
                setState(() => showSpelling = !showSpelling);
              } else if (value == 'gemmell') {
                _showSceneTools(scene);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'spelling',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.spellcheck_outlined),
                  title: Text(showSpelling ? 'Hide spelling' : 'Show spelling'),
                  subtitle: Text('${spelling.length} suggestion(s)'),
                ),
              ),
              if (gemmell.enabled)
                PopupMenuItem(
                  value: 'gemmell',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text('${gemmell.name} tools'),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _desktopSceneToolbar(StoryScene scene, List<SpellingIssue> spelling) =>
      Row(
        children: [
          IconButton(
            onPressed: preview ? null : () => _wrap('**'),
            tooltip: 'Bold (Ctrl+B)',
            icon: const Icon(Icons.format_bold, size: 19),
          ),
          IconButton(
            onPressed: preview ? null : () => _wrap('*'),
            tooltip: 'Italic (Ctrl+I)',
            icon: const Icon(Icons.format_italic, size: 19),
          ),
          IconButton(
            onPressed: preview ? null : _heading,
            tooltip: 'Heading',
            icon: const Icon(Icons.title, size: 20),
          ),
          _commonMarkMenu(scene),
          const Spacer(),
          IconButton(
            tooltip: spelling.isEmpty
                ? 'Deterministic spellcheck: no issues'
                : 'Spellcheck: ${spelling.length} suggestion(s)',
            onPressed: () => setState(() => showSpelling = !showSpelling),
            icon: Badge(
              isLabelVisible: spelling.isNotEmpty,
              label: Text('${spelling.length}'),
              child: const Icon(Icons.spellcheck_outlined, size: 19),
            ),
          ),
          if (gemmell.enabled)
            IconButton(
              tooltip: '${gemmell.name} tools',
              icon: const Icon(Icons.auto_awesome_outlined, size: 19),
              onPressed: () => _showSceneTools(scene),
            ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.edit_outlined, size: 16),
                label: Text('Write'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.visibility_outlined, size: 16),
                label: Text('View'),
              ),
            ],
            selected: {preview},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => preview = value.first),
          ),
          const SizedBox(width: 14),
          Text(
            '${scene.wordCount} words',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: const Color(0xFF7C786E)),
          ),
        ],
      );

  @override
  void dispose() {
    textController.removeListener(_changed);
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.controller.selectedScene!,
        section = widget.controller.sectionFor(scene),
        mobile = MediaQuery.sizeOf(context).width < 760,
        spelling = DeterministicSpellcheck.check(textController.text);
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFFBFAF6),
            border: Border(bottom: BorderSide(color: Color(0xFFE7E3D9))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 700
                ? _mobileSceneToolbar(scene, spelling)
                : _desktopSceneToolbar(scene, spelling),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: focusNode.requestFocus,
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 24 : 56,
                38,
                mobile ? 24 : 56,
                100,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section?.title.toUpperCase() ?? '',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: const Color(0xFF8B877B),
                            ),
                      ),
                      const SizedBox(height: 9),
                      InkWell(
                        onTap: () async {
                          final name = await _textDialog(
                            context,
                            'Rename scene',
                            scene.title,
                          );
                          if (name != null) {
                            widget.controller.renameScene(scene, name);
                          }
                        },
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                scene.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: Color(0xFF8B877B),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (showSpelling) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: spelling.isEmpty
                                ? const Text(
                                    'No deterministic spelling issues found.',
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Spelling suggestions'),
                                      const SizedBox(height: 8),
                                      for (final issue in spelling)
                                        Text(
                                          '“${issue.word}” → ${issue.suggestion}',
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (preview)
                        SelectionArea(
                          onSelectionChanged: (selection) {
                            previewSelection = selection?.plainText ?? '';
                          },
                          contextMenuBuilder: gemmell.enabled
                              ? (context, selectableRegionState) {
                                  final items = selectableRegionState
                                      .contextMenuButtonItems
                                      .toList();
                                  if (previewSelection.trim().isNotEmpty) {
                                    items.add(
                                      ContextMenuButtonItem(
                                        label: '${gemmell.name} tools…',
                                        onPressed: () {
                                          selectableRegionState.hideToolbar();
                                          _showSelectionToolsForText(
                                            scene,
                                            previewSelection,
                                          );
                                        },
                                      ),
                                    );
                                  }
                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: selectableRegionState
                                        .contextMenuAnchors,
                                    buttonItems: items,
                                  );
                                }
                              : null,
                          child: CommonMarkView(
                            data: textController.text,
                            selectable: false,
                            onSceneLink: (sceneId) {
                              final target = widget.controller.project!.sections
                                  .expand((section) => section.scenes)
                                  .where((scene) => scene.id == sceneId)
                                  .firstOrNull;
                              if (target != null) {
                                widget.controller.select(target);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This internal link points to a missing scene.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        )
                      else
                        Shortcuts(
                          shortcuts: const {
                            SingleActivator(
                              LogicalKeyboardKey.keyB,
                              control: true,
                            ): _BoldIntent(),
                            SingleActivator(
                              LogicalKeyboardKey.keyI,
                              control: true,
                            ): _ItalicIntent(),
                          },
                          child: Actions(
                            actions: {
                              _BoldIntent: CallbackAction<_BoldIntent>(
                                onInvoke: (_) {
                                  _wrap('**');
                                  return null;
                                },
                              ),
                              _ItalicIntent: CallbackAction<_ItalicIntent>(
                                onInvoke: (_) {
                                  _wrap('*');
                                  return null;
                                },
                              ),
                            },
                            child: TextField(
                              key: ValueKey(scene.id),
                              controller: textController,
                              focusNode: focusNode,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              autocorrect: true,
                              enableSuggestions: true,
                              contextMenuBuilder: gemmell.enabled
                                  ? (context, editableTextState) {
                                      final selection = editableTextState
                                          .textEditingValue
                                          .selection;
                                      final items = editableTextState
                                          .contextMenuButtonItems
                                          .toList();
                                      if (selection.isValid &&
                                          !selection.isCollapsed) {
                                        items.add(
                                          ContextMenuButtonItem(
                                            label: '${gemmell.name} tools…',
                                            onPressed: () {
                                              editableTextState.hideToolbar();
                                              _showSelectionTools(scene);
                                            },
                                          ),
                                        );
                                      }
                                      return AdaptiveTextSelectionToolbar.buttonItems(
                                        anchors: editableTextState
                                            .contextMenuAnchors,
                                        buttonItems: items,
                                      );
                                    }
                                  : null,
                              maxLines: null,
                              minLines: 18,
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: const InputDecoration(
                                hintText: 'Begin this scene…',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});
  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final titleController = TextEditingController(),
      authorController = TextEditingController();
  ProjectType type = ProjectType.prose;
  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = titleController.text.trim();
    if (title.isNotEmpty) {
      Navigator.pop(context, (title, authorController.text.trim(), type));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Start a new story'),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projects are ordinary folders kept together in Documents/Sutōrīraitā Projects. The example is installed as your own editable copy.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF6E6A61)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Project title',
              hintText: 'The Glass Harbour',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: authorController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Author',
              hintText: 'Your name',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<ProjectType>(
            isExpanded: true,
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Document model'),
            items: ProjectType.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(switch (value) {
                      ProjectType.prose => 'Prose',
                      ProjectType.screenplay => 'Screenplay',
                      ProjectType.interactiveFiction =>
                        'Interactive fiction (Story / Choice)',
                    }),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => type = value ?? type),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create project')),
    ],
  );
}

class ProjectSettingsDialog extends StatefulWidget {
  const ProjectSettingsDialog({super.key, required this.controller});
  final ProjectController controller;
  @override
  State<ProjectSettingsDialog> createState() => _ProjectSettingsDialogState();
}

class AppSettingsDialog extends StatefulWidget {
  const AppSettingsDialog({super.key, required this.controller});
  final ProjectController controller;
  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  late bool openLast = widget.controller.openLastProjectOnStartup;
  late bool experimental = widget.controller.experimentalEntityDetection;
  GemmellSettings gemmell = GemmellSettings();
  late final TextEditingController gemmellName = TextEditingController();
  late final TextEditingController gemmellPronouns = TextEditingController();

  Future<void> _setProseTransformation(bool enabled) async {
    if (!enabled) {
      setState(() => gemmell.proseTransformationEnabled = false);
      return;
    }
    if (!gemmell.enabled) return;
    final first = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable Prose Transformation?'),
        content: const Text(
          'These tools ask an external chatbot to generate replacement prose. They are disabled by default and always operate on selected text only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep disabled'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review the limits'),
        content: const Text(
          'Prompt Bridge never replaces manuscript text. Rewrites are proposals for manual review. Models can flatten voice, alter facts, invent connective material, or damage intentional choices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;
    final confirmation = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Type to enable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type ENABLE PROSE TRANSFORMATION to continue.'),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Confirmation phrase',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirmation.text == 'ENABLE PROSE TRANSFORMATION'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (typed == true && mounted) {
      setState(() => gemmell.proseTransformationEnabled = true);
    }
  }

  @override
  void initState() {
    super.initState();
    GemmellSettings.load().then((value) {
      if (!mounted) return;
      setState(() {
        gemmell = value;
        gemmellName.text = value.name;
        gemmellPronouns.text = value.pronouns;
      });
    });
  }

  @override
  void dispose() {
    gemmellName.dispose();
    gemmellPronouns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('App settings'),
    content: SizedBox(
      width: 470,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open current project on startup'),
              subtitle: const Text(
                'When off, Sutōrīraitā opens to the project list.',
              ),
              value: openLast,
              onChanged: (value) => setState(() => openLast = value),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Experimental object and event detection'),
              subtitle: const Text(
                'Also suggest repeated objects and events. Detection is deterministic and stays on-device.',
              ),
              value: experimental,
              onChanged: (value) => setState(() => experimental = value),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Gemmell assistant'),
              subtitle: const Text(
                'Disabled by default. Prompt Bridge only generates and copies a prompt; it sends nothing anywhere.',
              ),
              value: gemmell.enabled,
              onChanged: (value) => setState(() {
                gemmell.enabled = value;
                if (!value) gemmell.proseTransformationEnabled = false;
              }),
            ),
            if (gemmell.enabled) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Provider: Prompt Bridge'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gemmellName,
                decoration: const InputDecoration(labelText: 'Assistant name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gemmellPronouns,
                decoration: const InputDecoration(labelText: 'Pronouns'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: gemmell.tone,
                decoration: const InputDecoration(labelText: 'Assistant tone'),
                items: GemmellSettings.tones
                    .map(
                      (tone) =>
                          DropdownMenuItem(value: tone, child: Text(tone)),
                    )
                    .toList(),
                onChanged: (value) => gemmell.tone = value ?? gemmell.tone,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: gemmell.toneIntensity,
                decoration: const InputDecoration(labelText: 'Tone intensity'),
                items: GemmellSettings.toneIntensities.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text('${entry.key} — ${entry.value}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    gemmell.toneIntensity = value ?? gemmell.toneIntensity,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue:
                    GemmellSettings.editingStyles.contains(gemmell.editingStyle)
                    ? gemmell.editingStyle
                    : GemmellSettings.editingStyles.first,
                decoration: const InputDecoration(labelText: 'Editing style'),
                items: GemmellSettings.editingStyles
                    .map(
                      (style) =>
                          DropdownMenuItem(value: style, child: Text(style)),
                    )
                    .toList(),
                onChanged: (value) =>
                    gemmell.editingStyle = value ?? gemmell.editingStyle,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Prose Transformation',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Prose Transformation'),
                subtitle: const Text(
                  'Separately gated selection-only rewrite proposals. Never changes the manuscript automatically.',
                ),
                value: gemmell.proseTransformationEnabled,
                onChanged: _setProseTransformation,
              ),
            ],
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
        onPressed: () async {
          await widget.controller.setOpenLastProject(openLast);
          await widget.controller.setExperimentalEntityDetection(experimental);
          gemmell.name = gemmellName.text.trim().isEmpty
              ? 'Gemmell McGee'
              : gemmellName.text.trim();
          gemmell.pronouns = gemmellPronouns.text.trim().isEmpty
              ? 'they/them'
              : gemmellPronouns.text.trim();
          await gemmell.save();
          await widget.controller.setOpenLastProject(openLast);
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _ProjectSettingsDialogState extends State<ProjectSettingsDialog> {
  StoryProject get project => widget.controller.project!;
  late final TextEditingController title = TextEditingController(
        text: project.title,
      ),
      author = TextEditingController(text: project.author),
      language = TextEditingController(text: project.language),
      genreSearch = TextEditingController();
  late int autosave = widget.controller.autosaveDelayMs;
  late final Set<String> genres = project.genres.toSet();
  @override
  void dispose() {
    title.dispose();
    author.dispose();
    language.dispose();
    genreSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Project settings'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: author,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: language,
              decoration: const InputDecoration(labelText: 'Language'),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              initialValue: autosave,
              decoration: const InputDecoration(labelText: 'Autosave delay'),
              items: const [
                DropdownMenuItem(
                  value: 300,
                  child: Text('Very fast · 0.3 seconds'),
                ),
                DropdownMenuItem(
                  value: 700,
                  child: Text('Balanced · 0.7 seconds'),
                ),
                DropdownMenuItem(
                  value: 1500,
                  child: Text('Relaxed · 1.5 seconds'),
                ),
              ],
              onChanged: (value) => autosave = value ?? 700,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Genres · choose any that apply',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEE9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${genres.length} selected'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Genres combine their encyclopedia fields, subtypes, and relations. Selecting one does not replace another.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: genreSearch,
              decoration: const InputDecoration(
                labelText: 'Search genres',
                prefixIcon: Icon(Icons.search),
                hintText: 'Name or description',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final query = genreSearch.text.trim().toLowerCase();
                final packs =
                    [...GenrePacks.builtIns, ...project.customGenrePacks].where(
                      (pack) {
                        final description = GenrePacks.descriptionFor(pack);
                        return query.isEmpty ||
                            pack.name.toLowerCase().contains(query) ||
                            description.toLowerCase().contains(query);
                      },
                    ).toList();
                if (packs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No genres match this search.'),
                  );
                }
                return Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var index = 0; index < packs.length; index++) ...[
                        CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          value: genres.contains(packs[index].id),
                          title: Text(
                            '${packs[index].name}${project.customGenrePacks.contains(packs[index]) ? ' · imported' : ''}',
                          ),
                          subtitle: Text(
                            GenrePacks.descriptionFor(packs[index]),
                          ),
                          onChanged: (selected) => setState(() {
                            selected == true
                                ? genres.add(packs[index].id)
                                : genres.remove(packs[index].id);
                          }),
                        ),
                        if (index != packs.length - 1)
                          const Divider(height: 1, indent: 48),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    final pack = await widget.controller.store
                        .importGenrePack();
                    widget.controller.addGenrePack(pack);
                    setState(() => genres.add(pack.id));
                  } on ProjectCancelled {
                    // Native picker closed.
                  } catch (error) {
                    if (context.mounted) _showError(context, error);
                  }
                },
                icon: const Icon(Icons.extension_outlined),
                label: const Text('Import declarative .sutorigp pack'),
              ),
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
        onPressed: () async {
          await widget.controller.updateProjectSettings(
            title: title.text,
            author: author.text,
            language: language.text,
            autosaveDelay: autosave,
            genreIds: genres,
          );
          if (context.mounted) Navigator.pop(context, true);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class EmptyManuscript extends StatelessWidget {
  const EmptyManuscript({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.description_outlined,
          size: 38,
          color: Color(0xFF9B978C),
        ),
        const SizedBox(height: 12),
        Text(
          'Create a scene to begin',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: large ? 38 : 30,
        height: large ? 38 : 30,
        decoration: BoxDecoration(
          color: const Color(0xFF385D4B),
          borderRadius: BorderRadius.circular(large ? 11 : 8),
        ),
        child: Icon(
          Icons.edit_rounded,
          size: large ? 21 : 17,
          color: Colors.white,
        ),
      ),
      SizedBox(width: large ? 13 : 10),
      Flexible(
        child: Text(
          'Sutōrīraitā',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: large ? 24 : 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
      ),
    ],
  );
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});
  final SaveState state;
  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      SaveState.saved => (
        Icons.cloud_done_outlined,
        'Saved',
        const Color(0xFF668071),
      ),
      SaveState.saving => (Icons.sync, 'Saving…', const Color(0xFF777368)),
      SaveState.dirty => (Icons.circle, 'Editing', const Color(0xFFB18B4E)),
      SaveState.error => (
        Icons.error_outline,
        'Save failed',
        const Color(0xFFAA4F45),
      ),
    };
    return Tooltip(
      message: label,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          if (MediaQuery.sizeOf(context).width > 600) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 19), const SizedBox(width: 12), Text(label)],
  );
}

Future<void> _sceneAction(
  BuildContext context,
  ProjectController controller,
  StorySection section,
  StoryScene scene,
  String value,
) async {
  if (value == 'rename') {
    final name = await _textDialog(context, 'Rename scene', scene.title);
    if (name != null) controller.renameScene(scene, name);
  } else if (value == 'delete') {
    if (context.mounted &&
        await _confirm(context, 'Delete “${scene.title}”?')) {
      controller.deleteScene(scene);
    }
  } else if (value == 'move') {
    if (!context.mounted) return;
    final destination = await showDialog<StorySection>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Move scene to'),
        children: controller.project!.sections
            .where((item) => item != section)
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, item),
                child: Text(item.title),
              ),
            )
            .toList(),
      ),
    );
    if (destination != null) controller.moveScene(scene, destination);
  }
}

Future<void> _projectAction(
  BuildContext context,
  ProjectController controller,
  String value,
) async {
  try {
    if (value == 'library') {
      await controller.showProjectList();
      return;
    }
    if (value == 'settings') {
      await showDialog<bool>(
        context: context,
        builder: (_) => ProjectSettingsDialog(controller: controller),
      );
      return;
    }
    if (value == 'app-settings') {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AppSettingsDialog(controller: controller),
        );
      }
      return;
    }
    if (value == 'close') {
      await controller.closeProject();
      return;
    }
    if (value == 'package') {
      final projectType = controller.project!.type;
      final modeOption = switch (projectType) {
        ProjectType.screenplay => (
          'fountain',
          'Fountain screenplay (.fountain)',
          'Industry-readable plain-text screenplay',
        ),
        ProjectType.interactiveFiction => (
          'ink',
          'Ink story (.ink)',
          'Compiled from the Sōhōkō-sei Story / Choice IR',
        ),
        ProjectType.prose => (
          'novelist',
          'Novelist story (.nov)',
          'Chapters, scenes and encyclopedia; advanced formatting is simplified',
        ),
      };
      final selection = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Export story project'),
          children: [
            for (final option in [
              (
                'sutoriraita',
                'Sutōrīraitā (.sutoriraita)',
                'Complete native project backup',
              ),
              if (projectType == ProjectType.prose)
                (
                  'hammer',
                  'Hammer story (.hammer.zip)',
                  'Unzip into HammerProjects; preserves imported notes and timeline',
                ),
              modeOption,
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option.$1),
                child: ListTile(
                  title: Text(option.$2),
                  subtitle: Text(option.$3),
                ),
              ),
          ],
        ),
      );
      if (selection == null) return;
      await controller.saveNow();
      if (controller.saveState == SaveState.error) {
        throw StateError('Save failed. Resolve it before exporting.');
      }
      final project = controller.project!;
      final path = switch (selection) {
        'sutoriraita' => await controller.store.exportPackage(project),
        'fountain' => await controller.store.exportFountain(project),
        'ink' => await controller.store.exportInk(project),
        _ => await controller.store.exportStory(
          project,
          hammer: selection == 'hammer',
        ),
      };
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Exported to $path')));
      }
      return;
    }
    if (value == 'document-export') {
      final format = await _chooseExportFormat(context);
      if (format == null) return;
      await controller.saveNow();
      final path = await controller.store.exportDocument(
        controller.project!,
        format,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Exported to $path')));
      }
      return;
    }
    await controller.saveNow();
    final path = switch (value) {
      'package' => await controller.store.exportPackage(controller.project!),
      _ => '',
    };
    if (path.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Exported to $path')));
    }
  } on ProjectCancelled {
    // The user closed the native save picker.
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

Future<ManuscriptFormat?> _chooseExportFormat(BuildContext context) =>
    showDialog<ManuscriptFormat>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export manuscript'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final format in ManuscriptFormat.values)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text('${format.label} (.${format.extension})'),
                  subtitle: Text(format.description),
                  onTap: () => Navigator.pop(dialogContext, format),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

Future<String?> _textDialog(
  BuildContext context,
  String title,
  String initial,
) => showDialog<String>(
  context: context,
  builder: (_) => _TextValueDialog(title: title, initial: initial),
);

class _TextValueDialog extends StatefulWidget {
  const _TextValueDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_TextValueDialog> createState() => _TextValueDialogState();
}

class _TextValueDialogState extends State<_TextValueDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C443D),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> _strongConfirmation(BuildContext context, String phrase) async {
  final seed = DateTime.now().millisecondsSinceEpoch;
  final left = 2 + seed % 8;
  final right = 2 + (seed ~/ 10) % 8;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _StrongConfirmationDialog(phrase: phrase, left: left, right: right),
      ) ??
      false;
}

class _StrongConfirmationDialog extends StatefulWidget {
  const _StrongConfirmationDialog({
    required this.phrase,
    required this.left,
    required this.right,
  });
  final String phrase;
  final int left;
  final int right;

  @override
  State<_StrongConfirmationDialog> createState() =>
      _StrongConfirmationDialogState();
}

class _StrongConfirmationDialogState extends State<_StrongConfirmationDialog> {
  final phraseController = TextEditingController();
  final answerController = TextEditingController();

  bool get valid =>
      phraseController.text == widget.phrase &&
      int.tryParse(answerController.text.trim()) == widget.left + widget.right;

  @override
  void dispose() {
    phraseController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm bulk operation'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This affects every applicable story. Archived projects can be recovered; permanent deletion cannot be undone.',
          ),
          const SizedBox(height: 16),
          Text('Type exactly: ${widget.phrase}'),
          const SizedBox(height: 6),
          TextField(
            controller: phraseController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text('Safety check: ${widget.left} + ${widget.right} = ?'),
          const SizedBox(height: 6),
          TextField(
            controller: answerController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: valid ? () => Navigator.pop(context, true) : null,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9C443D)),
        child: const Text('Confirm'),
      ),
    ],
  );
}

void _showError(BuildContext context, Object error) {
  final message = error is FormatException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _NewSceneIntent extends Intent {
  const _NewSceneIntent();
}

class _BoldIntent extends Intent {
  const _BoldIntent();
}

class _ItalicIntent extends Intent {
  const _ItalicIntent();
}
