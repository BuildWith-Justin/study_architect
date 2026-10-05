import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/utils/calendar_heat.dart';

void main() {
  test('heatLevel maps minutes to 0-4', () {
    expect(heatLevel(0), 0);
    expect(heatLevel(-5), 0);
    expect(heatLevel(1), 1);
    expect(heatLevel(29), 1);
    expect(heatLevel(30), 2);
    expect(heatLevel(89), 2);
    expect(heatLevel(90), 3);
    expect(heatLevel(179), 3);
    expect(heatLevel(180), 4);
    expect(heatLevel(600), 4);
  });
}
