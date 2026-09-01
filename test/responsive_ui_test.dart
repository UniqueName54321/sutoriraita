import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/main.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/project_controller.dart';
import 'package:sutoriraita/project_store.dart';

StoryProject _project() {
  final now = DateTime.utc(2026, 9, 1);
  return StoryProject(
    id: 'responsive-project',
    title: 'A deliberately long mobile story title that must remain reachable',
    author: 'Writer',
    language: 'en-AU',
    createdAt: now,
    updatedAt: now,
    sections: [
      StorySection(
        id: 'chapter',
        title: 'A chapter with a deliberately long title',
        scenes: [
          StoryScene(
            id: 'scene',
            title: 'A scene with a deliberately long title for narrow screens',
            content: 'A misspeled paragraph with **CommonMark**.\n\n' * 12,
            updatedAt: now,
          ),
        ],
      ),
    ],
    encyclopedia: [
      EncyclopediaEntry(
        id: 'entry',
        title: 'A very long encyclopedia entry name',
        type: EncyclopediaType.character,
        content: 'Description.\n\n' * 10,
        updatedAt: now,
      ),
    ],
  );
}

class _NoSaveStore extends ProjectStore {
  _NoSaveStore(Directory documents)
    : super(documentsDirectory: () async => documents);

  @override
  Future<void> save(StoryProject project) async {}
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  double bottomInset = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);
}

Widget _scaledApp(Widget home, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Widget _workspace(ProjectController controller) => ListenableBuilder(
  listenable: controller,
  builder: (context, _) => WorkspaceScreen(controller: controller),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(320, 568), Size(568, 320), Size(600, 960)]) {
    testWidgets('workspace has no overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      await _setViewport(tester, size);
      final documents = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('responsive-ui-'),
      ))!;
      addTearDown(() => documents.delete(recursive: true));
      final controller = ProjectController(_NoSaveStore(documents))
        ..useProject(_project());
      addTearDown(controller.dispose);

      await tester.pumpWidget(_scaledApp(_workspace(controller), scale: 1.6));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffold.isDrawerOpen, isFalse);
      await tester.tap(find.byTooltip('Toggle manuscript'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(scaffold.isDrawerOpen, isTrue);
      expect(find.text('Story'), findsWidgets);
      expect(tester.takeException(), isNull);

      scaffold.closeDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(scaffold.isDrawerOpen, isFalse);

      controller.showArea(WorkspaceArea.encyclopedia);
      controller.selectEntry(controller.project!.encyclopedia.single);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editor and dialogs remain usable above the mobile keyboard', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 640), bottomInset: 260);
    final documents = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('responsive-keyboard-'),
    ))!;
    addTearDown(() => documents.delete(recursive: true));
    final controller = ProjectController(_NoSaveStore(documents))
      ..useProject(_project());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_scaledApp(_workspace(controller), scale: 2));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Write'));
    await tester.pump();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);

    final context = tester.element(find.byType(WorkspaceScreen));
    showDialog<void>(
      context: context,
      builder: (_) => const CreateProjectDialog(),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Start a new story'), findsOneWidget);
    expect(find.text('Create project'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project list remains usable on a small phone', (tester) async {
    await _setViewport(tester, const Size(320, 568));
    final documents = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('responsive-project-list-'),
    ))!;
    addTearDown(() => documents.delete(recursive: true));
    final controller = ProjectController(_NoSaveStore(documents));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _scaledApp(WelcomeScreen(controller: controller), scale: 2),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('YOUR PROJECTS'), findsOneWidget);
    expect(find.byTooltip('New project'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
