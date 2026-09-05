import 'package:flutter/material.dart';

import 'document_exporter.dart';
import 'models.dart';

class ExportDecision<T> {
  const ExportDecision.question(this.text, this.yes, this.no) : value = null;
  const ExportDecision.result(this.text, this.value) : yes = null, no = null;
  final String text;
  final T? value;
  final ExportDecision<T>? yes, no;
}

const manuscriptDecision = ExportDecision<ManuscriptFormat>.question(
  'Do you need a fixed page layout for printing?',
  ExportDecision.result(
    'PDF (.pdf) — fixed 6 × 9 inch pages.',
    ManuscriptFormat.pdf,
  ),
  ExportDecision.question(
    'Is this for an e-book reader?',
    ExportDecision.question(
      'Does your reader specifically require FictionBook 2?',
      ExportDecision.result(
        'FictionBook 2 (.fb2) — XML e-book.',
        ManuscriptFormat.fb2,
      ),
      ExportDecision.result(
        'EPUB (.epub) — reflowable e-book.',
        ManuscriptFormat.epub,
      ),
    ),
    ExportDecision.question(
      'Do you want a page to read in a web browser?',
      ExportDecision.result(
        'HTML (.html) — self-contained web page.',
        ManuscriptFormat.html,
      ),
      ExportDecision.question(
        'Will you edit it in Word or LibreOffice?',
        ExportDecision.result(
          'OpenDocument Text (.odt) — editable word-processing document.',
          ManuscriptFormat.odt,
        ),
        ExportDecision.question(
          'Do you want to keep Markdown formatting?',
          ExportDecision.result(
            'Markdown (.md) — editable formatting. Covers are omitted.',
            ManuscriptFormat.markdown,
          ),
          ExportDecision.result(
            'Plain text (.txt) — maximum compatibility. Covers are omitted.',
            ManuscriptFormat.text,
          ),
        ),
      ),
    ),
  ),
);

Future<ManuscriptFormat?> showManuscriptExportWizard(BuildContext context) =>
    showDialog<ManuscriptFormat>(
      context: context,
      builder: (_) => const ExportWizard(
        title: 'Export Manuscript Wizard',
        root: manuscriptDecision,
      ),
    );

Future<String?> showStoryExportWizard(BuildContext context, ProjectType type) {
  final alternative = switch (type) {
    ProjectType.prose => const ExportDecision<String>.question(
      'Will you open it in Hammer?',
      ExportDecision.result('Hammer (.hammer.zip)', 'hammer'),
      ExportDecision.result('Novelist (.nov)', 'novelist'),
    ),
    ProjectType.screenplay => const ExportDecision<String>.result(
      'Fountain (.fountain)',
      'fountain',
    ),
    ProjectType.interactiveFiction => const ExportDecision<String>.result(
      'Ink (.ink)',
      'ink',
    ),
    ProjectType.parserFictionPrototype => const ExportDecision<String>.result(
      'Sutōrīraitā (.sutoriraita)',
      'sutoriraita',
    ),
  };
  return showDialog<String>(
    context: context,
    builder: (_) => ExportWizard(
      title: 'Export Story Project Wizard',
      note: 'Cover images are omitted from story-project transfers.',
      root: ExportDecision.question(
        'Will you open this project in Sutōrīraitā?',
        const ExportDecision.result(
          'Sutōrīraitā (.sutoriraita)',
          'sutoriraita',
        ),
        alternative,
      ),
    ),
  );
}

class ExportWizard<T> extends StatefulWidget {
  const ExportWizard({
    super.key,
    required this.title,
    required this.root,
    this.note,
    this.confirmLabel = 'Export',
  });
  final String title;
  final ExportDecision<T> root;
  final String? note;
  final String confirmLabel;
  @override
  State<ExportWizard<T>> createState() => _ExportWizardState<T>();
}

class _ExportWizardState<T> extends State<ExportWizard<T>> {
  final List<ExportDecision<T>> history = [];
  ExportDecision<T> get current => history.isEmpty ? widget.root : history.last;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current.text),
            if (widget.note != null) ...[
              const SizedBox(height: 16),
              Text(widget.note!),
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
      if (history.isNotEmpty)
        TextButton(
          onPressed: () => setState(() => history.removeLast()),
          child: const Text('Back'),
        ),
      if (current.value == null) ...[
        TextButton(
          onPressed: () => setState(() => history.add(current.no!)),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => setState(() => history.add(current.yes!)),
          child: const Text('Yes'),
        ),
      ] else
        FilledButton(
          onPressed: () => Navigator.pop(context, current.value),
          child: Text(widget.confirmLabel),
        ),
    ],
  );
}
