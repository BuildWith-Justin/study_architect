import '../models/subject.dart';
import '../models/task.dart';
import '../utils/date_utils.dart';

enum QuickAddKind { session, task }

/// Start and end of a session built from a date, a start time and a
/// duration. A session that would run past midnight is cut at 23:59.
class SessionWindow {
  final DateTime start;
  final DateTime end;
  final bool clamped;

  const SessionWindow(this.start, this.end, this.clamped);

  bool get valid => end.isAfter(start);
}

/// What the parser understood. The quick-add sheet shows it for the
/// student to check and change before anything is saved.
class QuickAddResult {
  final bool hasContent;
  final QuickAddKind kind;
  final Subject? subject;
  final DateTime date; // day only
  final int startMinutes; // minutes since midnight
  final int durationMinutes;

  /// Task title, or the notes of a session.
  final String title;
  final TaskType taskType;
  final bool dateAssumed;
  final bool timeAssumed;
  final bool durationAssumed;
  final List<String> warnings;

  const QuickAddResult({
    required this.hasContent,
    required this.kind,
    required this.subject,
    required this.date,
    required this.startMinutes,
    required this.durationMinutes,
    required this.title,
    required this.taskType,
    required this.dateAssumed,
    required this.timeAssumed,
    required this.durationAssumed,
    required this.warnings,
  });

  factory QuickAddResult.empty(DateTime today) => QuickAddResult(
        hasContent: false,
        kind: QuickAddKind.session,
        subject: null,
        date: today,
        startMinutes: 17 * 60,
        durationMinutes: 60,
        title: '',
        taskType: TaskType.other,
        dateAssumed: true,
        timeAssumed: true,
        durationAssumed: true,
        warnings: const [],
      );
}

class _SubjectMatch {
  final Subject? subject;
  final String? matchedText;
  final bool ambiguous;

  const _SubjectMatch(this.subject, this.matchedText, this.ambiguous);
}

/// V2 Step 14d: turns a typed sentence such as
/// "Maths tomorrow 4pm 1h" or "task: finish lab report friday" into a
/// session or a task. Rule-based and offline: no API, no cost.
class QuickAddParser {
  QuickAddParser._();

  static const _defaultDuration = 60;

  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  static const _weekdays = [
    'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
  ];

  static const _stopWords = {
    'the', 'for', 'and', 'due', 'task', 'todo', 'study', 'session',
    'all', 'new', 'my', 'with',
  };

  static final _prefixRe = RegExp(
    r'^(task|todo|to-do|session)\b\s*[:\-]?\s*',
    caseSensitive: false,
  );
  static final _time12Re = RegExp(
    r'(?:\bat\s+)?\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
    caseSensitive: false,
  );
  static final _time24Re = RegExp(r'(?:\bat\s+)?\b([01]?\d|2[0-3]):([0-5]\d)\b');
  static final _isoRe = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
  static final _slashRe =
      RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');
  static const _monthNames =
      'january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|'
      'august|aug|september|sept|sep|october|oct|november|nov|december|dec';
  static final _dayMonthRe = RegExp(
    '\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+($_monthNames)\\b(?:\\s+(\\d{4}))?',
    caseSensitive: false,
  );
  static final _monthDayRe = RegExp(
    '\\b($_monthNames)\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b',
    caseSensitive: false,
  );
  static final _dayAfterRe =
      RegExp(r'\bday after tomorrow\b', caseSensitive: false);
  static final _relativeRe =
      RegExp(r'\b(today|tomorrow|tmrw|tmr)\b', caseSensitive: false);
  static final _inDaysRe =
      RegExp(r'\bin\s+(\d{1,3})\s+days?\b', caseSensitive: false);
  static final _weekdayRe = RegExp(
    r'\b(?:(next)\s+)?(monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thur|thu|friday|fri|saturday|sat|sunday|sun)\b',
    caseSensitive: false,
  );

  static final _durHM = RegExp(
    r'(?:\bfor\s+)?\b(\d+)\s*(?:h|hr|hrs|hours?)\s*(\d+)\s*(?:m|mins?|minutes?)\b',
    caseSensitive: false,
  );
  static final _durAttached =
      RegExp(r'(?:\bfor\s+)?\b(\d+)h(\d{1,2})\b', caseSensitive: false);
  static final _durHours = RegExp(
    r'(?:\bfor\s+)?\b(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hours?)\b',
    caseSensitive: false,
  );
  static final _durHalf = RegExp(
    r'(?:\bfor\s+)?\b(?:half an hour|half hour)\b',
    caseSensitive: false,
  );
  static final _durAnHour =
      RegExp(r'(?:\bfor\s+)?\b(?:an|one)\s+hour\b', caseSensitive: false);
  static final _durMinutes = RegExp(
    r'(?:\bfor\s+)?\b(\d+)\s*(?:m|mins?|minutes?)\b',
    caseSensitive: false,
  );

  static final _dueWordsRe = RegExp(
    r'\b(due|deadline|submit|submission|hand in)\b',
    caseSensitive: false,
  );
  static final _taskWordsRe = RegExp(
    r'\b(assignment|homework|report|essay|finish|complete|write|read|reading|project|lab)\b',
    caseSensitive: false,
  );

  static final _leadingFillersRe = RegExp(
    r'^(?:(?:due|by|on|at|for|in|to|the|a|an|my|of)\s+)+',
    caseSensitive: false,
  );
  static final _trailingFillersRe = RegExp(
    r'(?:\s+(?:due|by|on|at|for|in|to|the|a|an|my|of))+$',
    caseSensitive: false,
  );

  // ------------------------------------------------------------- public

  /// Builds the real start and end of a session.
  static SessionWindow sessionWindow(
    DateTime date,
    int startMinutes,
    int durationMinutes,
  ) {
    final d = startOfDay(date);
    final start = DateTime(d.year, d.month, d.day, startMinutes ~/ 60,
        startMinutes % 60);
    var end = start.add(Duration(minutes: durationMinutes));
    var clamped = false;
    if (!isSameDay(end, start)) {
      end = DateTime(d.year, d.month, d.day, 23, 59);
      clamped = true;
    }
    return SessionWindow(start, end, clamped);
  }

  static QuickAddResult parse(
    String input, {
    required List<Subject> subjects,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = startOfDay(current);
    var work = input.trim();
    if (work.isEmpty) return QuickAddResult.empty(today);

    final lowerOriginal = work.toLowerCase();
    final warnings = <String>[];

    // 1) explicit "task:" / "session:" prefix
    QuickAddKind? explicit;
    final prefix = _prefixRe.firstMatch(work);
    if (prefix != null) {
      explicit = prefix.group(1)!.toLowerCase() == 'session'
          ? QuickAddKind.session
          : QuickAddKind.task;
      work = work.substring(prefix.end);
    }

    // 2) time of day
    int? startMinutes;
    var tonight = false;

    final m12 = _time12Re.firstMatch(work);
    if (m12 != null) {
      var h = int.parse(m12.group(1)!);
      final min = int.tryParse(m12.group(2) ?? '0') ?? 0;
      final pm = m12.group(3)!.toLowerCase() == 'pm';
      if (h >= 1 && h <= 12 && min < 60) {
        if (h == 12) h = 0;
        if (pm) h += 12;
        startMinutes = h * 60 + min;
        work = _cut(work, m12);
      }
    }
    if (startMinutes == null) {
      final m24 = _time24Re.firstMatch(work);
      if (m24 != null) {
        startMinutes =
            int.parse(m24.group(1)!) * 60 + int.parse(m24.group(2)!);
        work = _cut(work, m24);
      }
    }
    if (startMinutes == null) {
      final words = <String, int>{
        'noon': 12 * 60,
        'morning': 8 * 60,
        'afternoon': 14 * 60,
        'evening': 18 * 60,
        'tonight': 19 * 60,
      };
      for (final entry in words.entries) {
        final m = RegExp('\\b${entry.key}\\b', caseSensitive: false)
            .firstMatch(work);
        if (m != null) {
          startMinutes = entry.value;
          if (entry.key == 'tonight') tonight = true;
          work = _cut(work, m);
          break;
        }
      }
    }

    // 3) date
    DateTime? date;

    var m = _isoRe.firstMatch(work);
    if (m != null) {
      final d = _safeDate(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
      if (d != null) {
        date = d;
        work = _cut(work, m);
      }
    }
    if (date == null) {
      m = _slashRe.firstMatch(work);
      if (m != null) {
        var year = m.group(3) == null ? null : int.parse(m.group(3)!);
        if (year != null && year < 100) year += 2000;
        final d = _resolveDayMonth(
          int.parse(m.group(1)!),
          int.parse(m.group(2)!),
          year,
          today,
        );
        if (d != null) {
          date = d;
          work = _cut(work, m);
        }
      }
    }
    if (date == null) {
      m = _dayMonthRe.firstMatch(work);
      if (m != null) {
        final d = _resolveDayMonth(
          int.parse(m.group(1)!),
          _monthIndex(m.group(2)!),
          m.group(3) == null ? null : int.parse(m.group(3)!),
          today,
        );
        if (d != null) {
          date = d;
          work = _cut(work, m);
        }
      }
    }
    if (date == null) {
      m = _monthDayRe.firstMatch(work);
      if (m != null) {
        final d = _resolveDayMonth(
          int.parse(m.group(2)!),
          _monthIndex(m.group(1)!),
          null,
          today,
        );
        if (d != null) {
          date = d;
          work = _cut(work, m);
        }
      }
    }
    if (date == null) {
      m = _dayAfterRe.firstMatch(work);
      if (m != null) {
        date = _addDays(today, 2);
        work = _cut(work, m);
      }
    }
    if (date == null) {
      m = _relativeRe.firstMatch(work);
      if (m != null) {
        final word = m.group(1)!.toLowerCase();
        date = word == 'today' ? today : _addDays(today, 1);
        work = _cut(work, m);
      }
    }
    if (date == null) {
      m = _inDaysRe.firstMatch(work);
      if (m != null) {
        date = _addDays(today, int.parse(m.group(1)!));
        work = _cut(work, m);
      }
    }
    if (date == null) {
      m = _weekdayRe.firstMatch(work);
      if (m != null) {
        final target = _weekdays.indexOf(m.group(2)!.toLowerCase().substring(0, 3)) + 1;
        var delta = (target - today.weekday) % 7;
        if (m.group(1) != null && delta == 0) delta = 7;
        date = _addDays(today, delta);
        work = _cut(work, m);
      }
    }
    if (date == null && tonight) {
      date = today;
    }

    // 4) duration
    int? duration;
    var dm = _durHM.firstMatch(work);
    if (dm != null) {
      duration = int.parse(dm.group(1)!) * 60 + int.parse(dm.group(2)!);
    } else if ((dm = _durAttached.firstMatch(work)) != null) {
      duration = int.parse(dm!.group(1)!) * 60 + int.parse(dm.group(2)!);
    } else if ((dm = _durHours.firstMatch(work)) != null) {
      duration = (double.parse(dm!.group(1)!) * 60).round();
    } else if ((dm = _durHalf.firstMatch(work)) != null) {
      duration = 30;
    } else if ((dm = _durAnHour.firstMatch(work)) != null) {
      duration = 60;
    } else if ((dm = _durMinutes.firstMatch(work)) != null) {
      duration = int.parse(dm!.group(1)!);
    }
    if (dm != null) {
      work = _cut(work, dm);
      if (duration != null && (duration < 5 || duration > 600)) {
        warnings.add('Duration must be between 5 minutes and 10 hours.');
        duration = null;
      }
    }

    // 5) kind
    QuickAddKind kind;
    if (explicit != null) {
      kind = explicit;
    } else if (_dueWordsRe.hasMatch(lowerOriginal)) {
      kind = QuickAddKind.task;
    } else if (startMinutes != null || duration != null) {
      kind = QuickAddKind.session;
    } else if (_taskWordsRe.hasMatch(lowerOriginal)) {
      kind = QuickAddKind.task;
    } else {
      kind = QuickAddKind.session;
    }

    // 6) subject and title
    var remaining = work.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = _matchSubject(remaining, subjects);
    if (match.ambiguous) {
      warnings.add('Several subjects match. Please choose one.');
    }
    if (match.matchedText != null) {
      remaining = remaining.replaceFirst(
        RegExp('\\b${RegExp.escape(match.matchedText!)}\\b',
            caseSensitive: false),
        ' ',
      );
    }
    var title = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(_leadingFillersRe, '');
    title = title.replaceAll(_trailingFillersRe, '');
    title = title.replaceAll(RegExp(r'^[\s:,\-]+|[\s:,\-]+$'), '').trim();
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }
    if (kind == QuickAddKind.task && title.isEmpty) {
      title = match.subject != null ? 'Task for ${match.subject!.name}' : '';
    }

    // 7) defaults
    final dateAssumed = date == null;
    final resolvedDate = date ?? today;

    final timeAssumed = startMinutes == null;
    final resolvedStart = startMinutes ??
        (isSameDay(resolvedDate, today)
            ? ((current.hour + 1) > 22 ? 22 : current.hour + 1) * 60
            : 17 * 60);

    final durationAssumed = duration == null;

    return QuickAddResult(
      hasContent: true,
      kind: kind,
      subject: match.subject,
      date: resolvedDate,
      startMinutes: resolvedStart,
      durationMinutes: duration ?? _defaultDuration,
      title: title,
      taskType: _taskTypeFor(lowerOriginal),
      dateAssumed: dateAssumed,
      timeAssumed: timeAssumed,
      durationAssumed: durationAssumed,
      warnings: warnings,
    );
  }

  // ------------------------------------------------------------ helpers

  static String _cut(String s, Match m) =>
      '${s.substring(0, m.start)} ${s.substring(m.end)}';

  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static int _monthIndex(String name) =>
      _months.indexOf(name.toLowerCase().substring(0, 3)) + 1;

  static DateTime? _safeDate(int y, int m, int d) {
    final date = DateTime(y, m, d);
    if (date.year == y && date.month == m && date.day == d) return date;
    return null;
  }

  static DateTime? _resolveDayMonth(
    int day,
    int month,
    int? year,
    DateTime today,
  ) {
    final y = year ?? today.year;
    var d = _safeDate(y, month, day);
    if (d == null) return null;
    if (year == null && d.isBefore(today)) {
      d = _safeDate(y + 1, month, day);
    }
    return d;
  }

  static TaskType _taskTypeFor(String lower) {
    if (RegExp(r'\bread(ing)?\b').hasMatch(lower)) return TaskType.reading;
    if (RegExp(r'\b(revis\w*|review)\b').hasMatch(lower)) {
      return TaskType.revision;
    }
    if (RegExp(r'\bproject\b').hasMatch(lower)) return TaskType.project;
    if (RegExp(r'\b(assignment|homework|report|essay|lab|submit)\b')
        .hasMatch(lower)) {
      return TaskType.assignment;
    }
    return TaskType.other;
  }

  static int _commonPrefix(String a, String b) {
    var i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) {
      i++;
    }
    return i;
  }

  static _SubjectMatch _matchSubject(String text, List<Subject> subjects) {
    final lower = text.toLowerCase();

    // 1) the whole subject name appears in the text
    Subject? phraseBest;
    var phraseLen = 0;
    for (final s in subjects) {
      final name = s.name.trim().toLowerCase();
      if (name.isEmpty) continue;
      final re = RegExp('\\b${RegExp.escape(name)}\\b');
      if (re.hasMatch(lower) && name.length > phraseLen) {
        phraseBest = s;
        phraseLen = name.length;
      }
    }
    if (phraseBest != null) {
      return _SubjectMatch(phraseBest, phraseBest.name.trim(), false);
    }

    // 2) a typed word starts like a word of the subject name
    //    ("maths" -> Mathematics, "chem" -> Chemistry)
    final tokens = RegExp(r"[a-z][a-z0-9']*")
        .allMatches(lower)
        .map((m) => m.group(0)!)
        .where((t) => t.length >= 3 && !_stopWords.contains(t))
        .toList();

    var bestScore = 0;
    final bestSubjects = <Subject>[];
    String? bestToken;

    for (final s in subjects) {
      final words = s.name
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3);
      var subjectScore = 0;
      String? subjectToken;
      for (final w in words) {
        for (final t in tokens) {
          final common = _commonPrefix(w, t);
          final shorter = w.length < t.length ? w.length : t.length;
          if (common >= 3 && common >= shorter - 1 && common > subjectScore) {
            subjectScore = common;
            subjectToken = t;
          }
        }
      }
      if (subjectScore == 0) continue;
      if (subjectScore > bestScore) {
        bestScore = subjectScore;
        bestSubjects
          ..clear()
          ..add(s);
        bestToken = subjectToken;
      } else if (subjectScore == bestScore) {
        bestSubjects.add(s);
      }
    }

    if (bestSubjects.isEmpty) return const _SubjectMatch(null, null, false);
    if (bestSubjects.length > 1) {
      return const _SubjectMatch(null, null, true);
    }
    return _SubjectMatch(bestSubjects.first, bestToken, false);
  }
}
