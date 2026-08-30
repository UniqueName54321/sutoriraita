class SpellingIssue {
  const SpellingIssue({required this.word, required this.suggestion});
  final String word;
  final String suggestion;
}

class DeterministicSpellcheck {
  static const _corrections = <String, String>{
    'adn': 'and',
    'becuase': 'because',
    'definately': 'definitely',
    'dont': "don't",
    'recieve': 'receive',
    'seperate': 'separate',
    'teh': 'the',
    'theirself': 'themself',
    'wierd': 'weird',
    'woudl': 'would',
    'youre': "you're",
  };

  static List<SpellingIssue> check(String markdown) {
    final issues = <SpellingIssue>[];
    final seen = <String>{};
    for (final match in RegExp(r"[A-Za-z']+").allMatches(markdown)) {
      final word = match.group(0)!;
      final correction = _corrections[word.toLowerCase()];
      if (correction != null && seen.add(word.toLowerCase())) {
        issues.add(SpellingIssue(word: word, suggestion: correction.trim()));
      }
    }
    final repeated = RegExp(
      r"\b([A-Za-z']+)\s+\1\b",
      caseSensitive: false,
    ).firstMatch(markdown);
    if (repeated != null) {
      issues.add(
        SpellingIssue(
          word: '${repeated.group(1)} ${repeated.group(1)}',
          suggestion: repeated.group(1)!,
        ),
      );
    }
    return issues;
  }
}
