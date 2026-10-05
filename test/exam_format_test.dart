import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/utils/exam_format.dart';

void main() {
  test('daysLeftLabel', () {
    expect(daysLeftLabel(-1), 'Past');
    expect(daysLeftLabel(0), 'Today');
    expect(daysLeftLabel(1), 'Tomorrow');
    expect(daysLeftLabel(12), '12 days');
  });

  test('examUrgency thresholds: calm above 14, soon at 14, urgent at 3', () {
    expect(examUrgency(-1), ExamUrgency.past);
    expect(examUrgency(0), ExamUrgency.urgent);
    expect(examUrgency(3), ExamUrgency.urgent);
    expect(examUrgency(4), ExamUrgency.soon);
    expect(examUrgency(14), ExamUrgency.soon);
    expect(examUrgency(15), ExamUrgency.calm);
  });

  test('date and time labels', () {
    final d = DateTime(2026, 10, 20, 9, 5);
    expect(examDateLabel(d), 'Tue, 20 Oct 2026');
    expect(examShortDateLabel(d), 'Tue, 20 Oct');
    expect(examTimeLabel(d), '09:05');
    expect(examTimeLabel(DateTime(2026, 1, 1, 14, 30)), '14:30');
  });
}
