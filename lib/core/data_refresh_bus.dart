import 'dart:async';

enum RefreshScope {
  subjects,
  sessions,
  tasks,
  exams,
  achievements,
  all,
}

class DataRefreshBus {
  DataRefreshBus._internal();
  static final DataRefreshBus instance = DataRefreshBus._internal();

  final StreamController<RefreshScope> _controller =
      StreamController<RefreshScope>.broadcast();

  Stream<RefreshScope> get stream => _controller.stream;

  void notify(RefreshScope scope) {
    _controller.add(scope);
  }

  void dispose() {
    _controller.close();
  }
}