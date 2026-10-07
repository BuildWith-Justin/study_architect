import 'package:flutter/material.dart';

import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../models/exam.dart';
import '../../models/exam_topic.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/exam_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../gamification/gamification_hooks.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/exam_format.dart';
import '../../widgets/gradient_background.dart';
import 'add_edit_exam_screen.dart';

class _TopicRow {
  final ExamTopic link;
  final Topic? topic;

  const _TopicRow(this.link, this.topic);
}

class _ExamDetailData {
  final Exam exam;
  final Subject? subject;
  final List<_TopicRow> rows;
  final ExamProgress progress;

  const _ExamDetailData({
    required this.exam,
    required this.subject,
    required this.rows,
    required this.progress,
  });
}

/// One exam: countdown, preparation progress and the topic checklist.
class ExamDetailScreen extends StatefulWidget {
  final String examId;

  const ExamDetailScreen({super.key, required this.examId});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen>
    with RefreshableScreenMixin<ExamDetailScreen> {
  late Future<_ExamDetailData?> _future;

  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.exams,
        RefreshScope.subjects,
      ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExamDetailData?> _load() async {
    final examRepo = ExamRepository();
    final exam = await examRepo.getById(widget.examId);
    if (exam == null) return null;

    final subject = await SubjectRepository().getById(exam.subjectId);
    final links = await examRepo.getTopicLinks(widget.examId);
    final topics = await TopicRepository().getForSubject(exam.subjectId);
    final topicsById = {for (final t in topics) t.id: t};

    final rows = [
      for (final l in links) _TopicRow(l, topicsById[l.topicId]),
    ];
    final prepared = links.where((l) => l.prepared).length;

    return _ExamDetailData(
      exam: exam,
      subject: subject,
      rows: rows,
      progress: ExamProgress(prepared: prepared, total: links.length),
    );
  }

  Future<void> _reload() async {
    final next = _load();

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

  Future<void> _setPrepared(ExamTopic link, bool value) async {
    try {
      await ExamRepository().setTopicPrepared(link.id, value);
      if (value) {
        await GamificationHooks.examTopicPrepared(link.id);
      } else {
        await GamificationHooks.examTopicUnprepared(link.id);
      }
      DataRefreshBus.instance.notify(RefreshScope.exams);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update that topic.')),
      );
    }
  }

  Future<void> _openEdit(Exam exam) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditExamScreen(existing: exam)),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmDelete(Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete exam?'),
        content: Text(
          '"${exam.title}" and its topic checklist will be removed. '
          'Your subject and topics are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await GamificationHooks.examRemoved(exam.id);
      await ExamRepository().delete(exam.id);
      DataRefreshBus.instance.notify(RefreshScope.exams);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the exam.')),
      );
    }
  }

  // ------------------------------------------------------------ UI pieces

  Widget _frame({required List<Widget> actions, required Widget child}) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Exam'),
                leading: const BackButton(),
                actions: actions,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.secondaryText),
            const SizedBox(height: AppSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, _ExamDetailData d) {
    final theme = Theme.of(context);
    final softWhite = Colors.white.withValues(alpha: 0.85);
    final exam = d.exam;
    final days = exam.daysLeft();

    final String big;
    final String small;
    if (days < 0) {
      big = 'Done';
      small = 'exam date has passed';
    } else if (days == 0) {
      big = 'Today';
      small = 'good luck!';
    } else if (days == 1) {
      big = '1';
      small = 'day left';
    } else {
      big = '$days';
      small = 'days left';
    }

    final progressText = d.progress.total == 0
        ? 'No topics added yet'
        : '${d.progress.prepared} of ${d.progress.total} topics ready'
            ' \u00B7 ${d.progress.percent}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.subject?.name ?? 'Unknown subject',
            style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
          ),
          const SizedBox(height: 2),
          Text(
            exam.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                big,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                small,
                style: theme.textTheme.bodyMedium?.copyWith(color: softWhite),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 15, color: softWhite),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${examDateLabel(exam.examDate)} \u00B7 '
                  '${examTimeLabel(exam.examDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
                ),
              ),
            ],
          ),
          if (exam.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 15, color: softWhite),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exam.location,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: softWhite),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: d.progress.fraction,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progressText,
            style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
          ),
        ],
      ),
    );
  }

  Widget _topicsCard(BuildContext context, _ExamDetailData d) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topics to prepare',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (d.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'No topics were added to this exam. Tap the pencil above '
                'to choose some.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.secondaryText,
                ),
              ),
            )
          else
            for (final row in d.rows)
              CheckboxListTile(
                value: row.link.prepared,
                onChanged: (value) => _setPrepared(row.link, value == true),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: Text(
                  row.topic?.name ?? 'Removed topic',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: row.link.prepared
                        ? context.secondaryText
                        : context.primaryText,
                    decoration:
                        row.link.prepared ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _notesCard(BuildContext context, String notes) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            notes,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExamDetailData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _frame(
            actions: const [],
            child: _message(
              context,
              Icons.error_outline_rounded,
              'Could not load this exam.',
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return _frame(
            actions: const [],
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return _frame(
            actions: const [],
            child: _message(
              context,
              Icons.search_off_rounded,
              'This exam no longer exists.',
            ),
          );
        }

        return _frame(
          actions: [
            IconButton(
              onPressed: () => _openEdit(data.exam),
              tooltip: 'Edit exam',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _confirmDelete(data.exam),
              tooltip: 'Delete exam',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _hero(context, data),
                const SizedBox(height: AppSpacing.md),
                _topicsCard(context, data),
                if (data.exam.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _notesCard(context, data.exam.notes),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}
