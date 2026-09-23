
import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/app/startup_decider.dart';

void main() {
  testWidgets('Study Architect starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const StartupDecider());

    await tester.pump();

    expect(find.byType(StartupDecider), findsOneWidget);
  });
}
