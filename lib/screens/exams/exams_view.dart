import 'package:flutter/material.dart';

import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/exam_format.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/exam_list_tile.dart';
import 'add_edit_exam_screen.dart';
import 'exam_detail_screen.dart';
import 'exams_view_data.dart';

/// The list of exams. Used inside the Subjects tab (Exams side of the
/// toggle) and inside the standalone ExamsScreen.
class ExamsView extends StatefulWidget {
  const ExamsView({super.key});

  @override
  State<ExamsView> createState() => _ExamsViewState();
}

class _ExamsViewState extends State<ExamsView>
    with WidgetsBindingObserver, RefreshableScreenMixin<ExamsView> {
  late Future<ExamsViewData> _future;

  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.exams,
        RefreshScope.subjects,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = ExamsViewData.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Days left change at midnight, so reload when the app comes back.
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final next = ExamsViewData.load();

    if (!mounted) {
      next.ignore();
      return;
    }

    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the error state.
    }
  }

  @override
  Future<void> onRefresh() => _reload();

  Future<void> _openAdd() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditExamScreen()),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openDetail(String examId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: examId)),
    );
    if (!mounted) return;
    await _reload();
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _tile(BuildContext context, ExamSummary s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExamListTile(
        title: s.exam.title,
        subjectName: s.subject?.name ?? 'Unknown subject',
        accent: s.subject != null
            ? Color(s.subject!.colorValue)
            : AppColors.primary,
        dateLabel: examShortDateLabel(s.exam.examDate),
        daysLeft: s.exam.daysLeft(),
        progress: s.progress,
        onTap: () => _openDetail(s.exam.id),
      ),
    );
  }

  Widget _emptyList(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 40,
                  color: context.secondaryText,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No exams yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add an exam to track your preparation.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.secondaryText,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: 220,
                  child: PrimaryButton(
                    label: 'Add exam',
                    icon: Icons.add_rounded,
                    onPressed: _openAdd,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _examList(BuildContext context, ExamsViewData data) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (data.upcoming.isNotEmpty) ...[
          _sectionLabel(context, 'Upcoming'),
          for (final s in data.upcoming) _tile(context, s),
        ],
        if (data.past.isNotEmpty) ...[
          if (data.upcoming.isNotEmpty) const SizedBox(height: AppSpacing.md),
          _sectionLabel(context, 'Past'),
          for (final s in data.past) _tile(context, s),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExamsViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: context.secondaryText,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Could not load exams.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _reload,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final upcomingCount = data.upcoming.length;
        final countLabel = upcomingCount == 0
            ? 'No upcoming exams'
            : upcomingCount == 1
                ? '1 upcoming exam'
                : '$upcomingCount upcoming exams';

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    countLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  IconButton.filled(
                    onPressed: _openAdd,
                    tooltip: 'Add exam',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: data.isEmpty
                      ? _emptyList(context)
                      : _examList(context, data),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
