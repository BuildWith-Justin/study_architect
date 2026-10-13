/// The only education levels a student can choose (onboarding and
/// Edit profile). Values are stored exactly as written here.
class EducationLevels {
  EducationLevels._();

  static const List<String> options = [
    'Level 100',
    'Level 200',
    'Level 300',
    'Level 400',
    'Postgraduate',
  ];

  /// Maps any saved text (for example "200" or "level 300") to one of
  /// [options]. Returns null when nothing matches.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    for (final option in options) {
      if (option.toLowerCase() == text) return option;
    }

    if (text.contains('postgrad') ||
        text.contains('post-grad') ||
        text.contains('post grad') ||
        text.contains('master') ||
        text.contains('msc') ||
        text.contains('mphil') ||
        text.contains('phd')) {
      return 'Postgraduate';
    }

    final match = RegExp(r'(?<!\d)([1-4])00(?!\d)').firstMatch(text);
    if (match != null) return 'Level ${match.group(1)}00';

    return null;
  }
}
