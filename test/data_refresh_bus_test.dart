import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/core/data_refresh_bus.dart';

void main() {
  test('DataRefreshBus delivers events to listeners in order', () async {
    final received = <RefreshScope>[];
    final sub = DataRefreshBus.instance.stream.listen(received.add);

    DataRefreshBus.instance.notify(RefreshScope.sessions);
    DataRefreshBus.instance.notify(RefreshScope.tasks);

    await Future.delayed(Duration.zero);

    expect(received, [RefreshScope.sessions, RefreshScope.tasks]);
    await sub.cancel();
  });
}