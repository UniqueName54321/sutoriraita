class InternalSceneLink {
  const InternalSceneLink({
    required this.start,
    required this.end,
    required this.label,
    required this.sceneId,
  });

  final int start;
  final int end;
  final String label;
  final String sceneId;
}

class InternalLinks {
  static final _pattern = RegExp(r'\[([^\]]+)\]\(scene:([^\s)]+)\)');

  static Iterable<InternalSceneLink> parse(String source) => _pattern
      .allMatches(source)
      .map(
        (match) => InternalSceneLink(
          start: match.start,
          end: match.end,
          label: match.group(1)!,
          sceneId: match.group(2)!,
        ),
      );

  static String markdown(String label, String sceneId) =>
      '[$label](scene:$sceneId)';

  static String anchor(String sceneId) =>
      'scene-${sceneId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '-')}';

  static String resolveForWeb(String source, Set<String> sceneIds) {
    return source.replaceAllMapped(_pattern, (match) {
      final id = match.group(2)!;
      if (!sceneIds.contains(id)) return match.group(0)!;
      return '[${match.group(1)}](#${anchor(id)})';
    });
  }

  static String resolveForPrint(String source, Map<String, int> scenePages) {
    return source.replaceAllMapped(_pattern, (match) {
      final page = scenePages[match.group(2)!];
      return page == null
          ? '${match.group(1)} (missing scene)'
          : '${match.group(1)} (page $page)';
    });
  }
}
