import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/models/subject.dart';
import 'package:study_architect/models/task.dart';
import 'package:study_architect/services/quick_add_parser.dart';

Subject _subject(String id, String name) => Subject(
      id: id,
      name: name,
      difficulty: SubjectDifficulty.medium,
      colorValue: 0xFF7C4DFF,
      weeklyTargetMinutes: 0,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  // Wednesday 7 October 2026, 10:00.
  final now = DateTime(2026, 10, 7, 10);
  final subjects = [
    _subject('m', 'Mathematics'),
    _subject('p', 'Physics'),
    _subject('c', 'Chemistry'),
  ];

  QuickAddResult parse(String text, {List<Subject>? list}) =>
      QuickAddParser.parse(text, subjects: list ?? subjects, now: now);

  test('blank input has no content', () {
    expect(parse('   ').hasContent, isFalse);
  });

  test('"Maths tomorrow 4pm 1h" is a session for Mathematics', () {
    final r = parse('Maths tomorrow 4pm 1h');
    expect(r.kind, QuickAddKind.session);
    expect(r.subject?.id, 'm');
    expect(r.date, DateTime(2026, 10, 8));
    expect(r.startMinutes, 16 * 60);
    expect(r.durationMinutes, 60);
  });

  test('"task: finish lab report friday" is a task with no subject', () {
    final r = parse('task: finish lab report friday');
    expect(r.kind, QuickAddKind.task);
    expect(r.subject, isNull);
    expect(r.date, DateTime(2026, 10, 9));
    expect(r.title, 'Finish lab report');
    expect(r.taskType, TaskType.assignment);
  });

  test('24-hour time and minutes duration', () {
    final r = parse('physics 18:30 for 90 min');
    expect(r.kind, QuickAddKind.session);
    expect(r.subject?.id, 'p');
    expect(r.date, DateTime(2026, 10, 7));
    expect(r.startMinutes, 18 * 60 + 30);
    expect(r.durationMinutes, 90);
  });

  test('"in 3 days" and hours duration', () {
    final r = parse('chem revision in 3 days 2h');
    expect(r.subject?.id, 'c');
    expect(r.date, DateTime(2026, 10, 10));
    expect(r.durationMinutes, 120);
    expect(r.title, 'Revision');
  });

  test('day and month name', () {
    final r = parse('12 oct 5pm math');
    expect(r.date, DateTime(2026, 10, 12));
    expect(r.startMinutes, 17 * 60);
    expect(r.subject?.id, 'm');
  });

  test('"next monday" gives the coming Monday', () {
    final r = parse('Physics next monday 9am');
    expect(r.date, DateTime(2026, 10, 12));
    expect(r.startMinutes, 9 * 60);
  });

  test('duration formats', () {
    expect(parse('maths 1h30').durationMinutes, 90);
    expect(parse('maths 45 min').durationMinutes, 45);
    expect(parse('maths 2 hours').durationMinutes, 120);
    expect(parse('maths half an hour').durationMinutes, 30);
  });

  test('ambiguous subject names are not guessed', () {
    final list = [_subject('a', 'English'), _subject('b', 'Engineering')];
    final r = parse('eng tomorrow 3pm', list: list);
    expect(r.subject, isNull);
    expect(r.warnings, isNotEmpty);
  });

  test('a full name beats a shared prefix', () {
    final list = [_subject('a', 'English'), _subject('b', 'Engineering')];
    expect(parse('english tomorrow 3pm', list: list).subject?.id, 'a');
  });

  test('defaults are flagged as assumed', () {
    final r = parse('maths');
    expect(r.dateAssumed, isTrue);
    expect(r.timeAssumed, isTrue);
    expect(r.durationAssumed, isTrue);
    expect(r.durationMinutes, 60);
  });

  test('a session that would pass midnight is cut at 23:59', () {
    final w = QuickAddParser.sessionWindow(DateTime(2026, 10, 7), 23 * 60, 120);
    expect(w.clamped, isTrue);
    expect(w.valid, isTrue);
    expect(w.end, DateTime(2026, 10, 7, 23, 59));
  });
}
