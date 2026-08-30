import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class CommonMarkView extends StatelessWidget {
  const CommonMarkView({
    super.key,
    required this.data,
    this.selectable = true,
    this.onSceneLink,
  });
  final String data;
  final bool selectable;
  final ValueChanged<String>? onSceneLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: data,
      selectable: selectable,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (_, href, _) {
        if (href?.startsWith('scene:') == true) {
          onSceneLink?.call(href!.substring('scene:'.length));
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge,
        strong: const TextStyle(fontWeight: FontWeight.w800),
        em: const TextStyle(fontStyle: FontStyle.italic),
        h1: theme.textTheme.headlineLarge,
        h2: theme.textTheme.headlineMedium,
        h3: theme.textTheme.titleLarge,
        blockquote: theme.textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF5F6F65),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF668071), width: 3)),
        ),
        code: const TextStyle(
          fontFamily: 'Consolas',
          fontSize: 14,
          color: Color(0xFF284D3C),
          backgroundColor: Color(0xFFEAE7DE),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFEAE7DE),
          borderRadius: BorderRadius.circular(8),
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFD6D1C5))),
        ),
      ),
    );
  }
}
