import 'package:flutter/material.dart';

import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../models/exam.dart';
import '../../repositories/exam_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/exam_format.dart';
import '../exams/exam_detail_screen.dart';
import '../exams/exams_screen.dart';
import '../exams/exams_view_data.dart';

/// Slim card on Home showing the nearest exam. The arrow expands it to
/// reveal up to three more. It hides itself when no exam is coming up in
/// the next 30 days, so Home stays as quiet as before.
class NextExamCard extends StatefulWidget {
  /// Changes every time Home reloads, so the card reloads with it
  /// (pull to refresh, returning from another screen, app resume).
  final int loadToken;

  const NextExamCard({super.key, this.loadToken = 0});

  @override
  State<NextExamCard> createState() => _NextExamCardState();
}

class _NextExamCardState extends State<NextExamCard>
    with WidgetsBindingObserver, RefreshableScreenMixin<NextExamCard> {
  static const _windowDays = 30;
  static const _maxExtra = 3;

  List<ExamSummary> _items = const [];
  bool _expanded = false;

  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.exams,
        RefreshScope.subjects,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NextExamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadToken != widget.loadToken) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  @override
  Future<void> onRefresh() => _load();

  Future<void> _load() async {
    try {
      final repo = ExamRepository();
      final upcoming = await repo.getUpcoming(limit: 12);
      final subjects = await SubjectRepository().getAll();
      final progress = await repo.getProgressForAll();
      final subjectsById = {for (final s in subjects) s.id: s};

      final items = <ExamSummary>[];
      for (final exam in upcoming) {
        // Sorted nearest first, so the first one outside the window ends it.
        if (exam.daysLeft() > _windowDays) break;
        items.add(
          ExamSummary(
            exam: exam,
            subject: subjectsById[exam.subjectId],
            progress: progress[exam.id] ?? const ExamProgress.empty(),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _items = items.take(_maxExtra + 1).toList();
        if (_items.length <= 1) _expanded = false;
      });
    } catch (_) {
      // The card is optional: keep showing what we had.
    }
  }

  Future<void> _openDetail(String examId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: examId)),
    );
    if (mounted) await _load();
  }

  Future<void> _openAll() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ExamsScreen()),
    );
    if (mounted) await _load();
  }

  Color _accent(ExamSummary s) =>
      s.subject != null ? Color(s.subject!.colorValue) : AppColors.primary;

  Widget _progressRow(BuildContext context, ExamSummary s, Color color) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.progress.fraction,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          s.progress.total == 0 ? 'No topics' : '${s.progress.percent}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
              ),
        ),
      ],
    );
  }

  Widget _mainRow(BuildContext context, ExamSummary s, Color urgencyColor) {
    final theme = Theme.of(context);
    final days = s.exam.daysLeft();

    return InkWell(
      onTap: () => _openDetail(s.exam.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.school_rounded, color: urgencyColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.exam.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        daysLeftLabel(days),
                        style: TextStyle(
                          color: urgencyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.subject?.name ?? 'Unknown subject'} \u00B7 '
                    '${examShortDateLabel(s.exam.examDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _progressRow(context, s, urgencyColor),
                ],
              ),
            ),
            if (_items.length > 1)
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                tooltip: _expanded ? 'Hide other exams' : 'Show more exams',
                color: context.secondaryText,
                icon: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.secondaryText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _extraRow(BuildContext context, ExamSummary s) {
    final theme = Theme.of(context);
    final days = s.exam.daysLeft();
    final color = examUrgencyColor(context, examUrgency(days));

    return InkWell(
      onTap: () => _openDetail(s.exam.id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: context.secondaryText.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.exam.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  daysLeftLabel(days),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${s.subject?.name ?? 'Unknown subject'} \u00B7 '
              '${examShortDateLabel(s.exam.examDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
              ),
            ),
            const SizedBox(height: 6),
            _progressRow(context, s, _accent(s)),
          ],
        ),
      ),
    );
  }

  Widget _expandedPart(BuildContext context) {
    return Column(
      children: [
        for (final s in _items.skip(1)) _extraRow(context, s),
        InkWell(
          onTap: _openAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.secondaryText.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: const Text(
              'See all exams',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final first = _items.first;
    final urgencyColor =
        examUrgencyColor(context, examUrgency(first.exam.daysLeft()));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: context.cardSurfaceAlt,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: urgencyColor, width: 1.5),
        ),
        child: Column(
          children: [
            _mainRow(context, first, urgencyColor),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _expandedPart(context)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
