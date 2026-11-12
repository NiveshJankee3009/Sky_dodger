/// Pure helpers for the online features (kept free of Firebase so they can be
/// unit tested).
library;

/// Nickname rules: 3-15 characters, letters/numbers/underscore, at least one
/// letter, nothing offensive. Returns an error message, or null when valid.
String? validateNickname(String raw) {
  final nick = raw.trim();
  if (nick.length < 3) return 'At least 3 characters';
  if (nick.length > 15) return 'At most 15 characters';
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(nick)) {
    return 'Only letters, numbers and _';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(nick)) return 'Include at least one letter';
  if (_isOffensive(nick)) return 'Please choose another nickname';
  return null;
}

/// Normalised key used to keep nicknames unique regardless of case.
String nicknameKey(String nick) => nick.trim().toLowerCase();

// A deliberately small list; substrings are matched after removing
// underscores and swapping common look-alike digits (0->o, 1->i, 3->e, ...).
const _blocked = [
  'fuck', 'shit', 'bitch', 'cunt', 'dick', 'pussy', 'nigg', 'fag', 'slut',
  'whore', 'nazi', 'hitler', 'porn', 'sex', 'penis', 'vagina',
  'bastard', 'asshole', 'merde', 'putain', 'salope', 'connard', 'encule',
  'admin', 'moderator', 'skydodger',
];

bool _isOffensive(String nick) {
  final s = nick
      .toLowerCase()
      .replaceAll('_', '')
      .replaceAll('0', 'o')
      .replaceAll('1', 'i')
      .replaceAll('3', 'e')
      .replaceAll('4', 'a')
      .replaceAll('5', 's')
      .replaceAll('7', 't')
      .replaceAll('8', 'b')
      .replaceAll('@', 'a');
  return _blocked.any(s.contains);
}

/// ISO-8601 week id in UTC, e.g. "2026-W46". Weekly boards reset on Monday
/// 00:00 UTC (04:00 in Mauritius).
String isoWeekId(DateTime time) {
  final t = time.toUtc();
  final day = DateTime.utc(t.year, t.month, t.day);
  // The ISO week belongs to the year that contains its Thursday.
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final firstDay = DateTime.utc(thursday.year, 1, 1);
  final week = thursday.difference(firstDay).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Highest score the server rules accept (also enforced in firestore.rules).
const int maxAcceptedScore = 1000000;
