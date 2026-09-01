import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutoriraita/main.dart';
import 'package:sutoriraita/mode_editors.dart';
import 'package:sutoriraita/mode_formats.dart';
import 'package:sutoriraita/models.dart';
import 'package:sutoriraita/project_controller.dart';
import 'package:sutoriraita/project_store.dart';

StoryProject _project(ProjectType type) {
  final now = DateTime.utc(2026, 9, 1);
  final scene = StoryScene(
    id: 'scene',
    title: 'INT. LAB - DAY',
    content: '',
    updatedAt: now,
  );
  final start = IfNode(
    id: 'start',
    title: 'Start',
    content: 'A locked door.',
    choices: [
      IfChoice(
        id: 'choice',
        label: 'Open it',
        targetNodeId: 'ending',
        condition: 'has_key',
      ),
    ],
    effects: [IfEffect(variable: 'visits', expression: 'visits + 1')],
  );
  return StoryProject(
    id: 'project',
    title: 'Mode test',
    author: 'Writer',
    language: 'en',
    createdAt: now,
    updatedAt: now,
    type: type,
    sections: [
      StorySection(id: 'section', title: 'Screenplay', scenes: [scene]),
    ],
    screenplay: {
      scene.id: [
        ScreenplayElement(
          id: 'heading',
          type: ScreenplayElementType.sceneHeading,
          text: 'INT. LAB - DAY',
        ),
        ScreenplayElement(
          id: 'action',
          type: ScreenplayElementType.action,
          text: 'Rain attacks the windows.',
        ),
        ScreenplayElement(
          id: 'character',
          type: ScreenplayElementType.character,
          text: 'MAYA',
        ),
        ScreenplayElement(
          id: 'dialogue',
          type: ScreenplayElementType.dialogue,
          text: 'We begin.',
        ),
      ],
    },
    interactiveFiction: SohoIr(
      variables: {'has_key': 'true', 'visits': '0'},
      startNodeId: start.id,
      nodes: [
        start,
        IfNode(
          id: 'ending',
          title: 'Outside',
          content: 'Freedom.',
          isEnding: true,
        ),
      ],
    ),
  );
}

class _NoSaveStore extends ProjectStore {
  _NoSaveStore(Directory directory)
    : super(documentsDirectory: () async => directory);
  @override
  Future<void> save(StoryProject project) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('old manifests remain prose and new mode data round-trips', () {
    final old = StoryProject.fromJson({
      'id': 'old',
      'title': 'Old story',
      'author': '',
      'language': 'en',
      'sections': <Object?>[],
    });
    expect(old.type, ProjectType.prose);

    for (final type in [
      ProjectType.screenplay,
      ProjectType.interactiveFiction,
    ]) {
      final source = _project(type);
      final decoded = StoryProject.fromJson(
        jsonDecode(source.prettyJson()) as Map<String, Object?>,
      );
      expect(decoded.type, type);
      if (type == ProjectType.screenplay) {
        expect(
          decoded.screenplay['scene']?.map((item) => item.type),
          contains(ScreenplayElementType.character),
        );
      } else {
        expect(decoded.interactiveFiction.startNodeId, 'start');
        expect(
          decoded.interactiveFiction.nodes.first.choices.single.condition,
          'has_key',
        );
      }
    }
  });

  test('Fountain conversion keeps screenplay semantics', () {
    final encoded = FountainFormat.encode(_project(ProjectType.screenplay));
    expect(encoded, contains('INT. LAB - DAY'));
    expect(encoded, contains('MAYA'));
    expect(encoded, contains('We begin.'));
    final decoded = FountainFormat.decode(encoded);
    expect(
      decoded.single.elements.map((item) => item.type),
      containsAll([
        ScreenplayElementType.sceneHeading,
        ScreenplayElementType.character,
        ScreenplayElementType.dialogue,
      ]),
    );
  });

  test('Sōhōkō-sei exports valid Ink-shaped story and choice flow', () {
    final ink = SohoInkExporter.encode(
      _project(ProjectType.interactiveFiction),
    );
    expect(ink, contains('VAR has_key = true'));
    expect(ink, contains('-> start'));
    expect(ink, contains('{has_key} [Open it]'));
    expect(ink, contains('~ visits = visits + 1'));
    expect(ink, contains('=== ending ==='));
  });

  test(
    'screenplay and IF projects persist and reopen in their native models',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'document-models-',
      );
      addTearDown(() => documents.delete(recursive: true));
      final store = ProjectStore(documentsDirectory: () async => documents);
      for (final type in [
        ProjectType.screenplay,
        ProjectType.interactiveFiction,
      ]) {
        final created = await store.create(
          title: type.label,
          author: '',
          type: type,
        );
        final reopened = await store.open(created.path);
        expect(reopened.type, type);
        if (type == ProjectType.screenplay) {
          expect(reopened.screenplay.values.single, isNotEmpty);
        } else {
          expect(reopened.interactiveFiction.nodes.single.title, 'Start');
          expect(reopened.interactiveFiction.startNodeId, isNotNull);
        }
      }
    },
  );

  testWidgets('creation dialog offers all document models', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreateProjectDialog())),
    );
    expect(find.text('Document model'), findsOneWidget);
    await tester.tap(find.text('Prose').last);
    await tester.pumpAndSettle();
    expect(find.text('Screenplay'), findsOneWidget);
    expect(find.text('Interactive fiction (Story / Choice)'), findsOneWidget);
  });

  for (final type in [ProjectType.screenplay, ProjectType.interactiveFiction]) {
    testWidgets('${type.key} editor fits a small phone', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('mode-widget-'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      final controller = ProjectController(_NoSaveStore(directory))
        ..useProject(_project(type));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: type == ProjectType.screenplay
                ? ScreenplayEditor(controller: controller)
                : InteractiveFictionEditor(controller: controller),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (type == ProjectType.interactiveFiction) {
        expect(find.text('Play/Test'), findsOneWidget);
        expect(find.text('Passage'), findsOneWidget);
      }
    });
  }
}
