import '../../models/settings.dart';
import '../../models/student.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/student_repository.dart';

class MoreViewData {
  final Student student;
  final AppSettings settings;

  const MoreViewData({required this.student, required this.settings});

  static Future<MoreViewData> load() async {
    final student = await StudentRepository().getCurrent();
    final settings = await SettingsRepository().get();
    if (student == null) {
      throw StateError('MoreViewData.load() called before onboarding completed.');
    }
    return MoreViewData(student: student, settings: settings);
  }
}