import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../models/study_session.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../repositories/session_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/async_builder.dart';
import '../../widgets/topic_row.dart';
import '../session/focus_timer_screen.dart';
import 'add_edit_subject_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with WidgetsBindingObserver {
  final _subjectRepo = SubjectRepository();
  final _topicRepo = TopicRepository();
  final _sessionRepo = SessionRepository();

  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  Future<_DetailData> _load() async {
    final subject = await _subjectRepo.getById(widget.subjectId);

    if (subject == null) {
      throw StateError('Subject not found');
    }

    final topics = await _topicRepo.getForSubject(widget.subjectId);
    final sessions = await _sessionRepo.getForSubject(widget.subjectId);

    return _DetailData(
      subject: subject,
      topics: topics,
      sessions: sessions,
    );
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    final future = _load();

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // AsyncBuilder will display the error state.
    }
  }

  Future<void> _addTopic(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New topic'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Differential Equations',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                controller.text.trim(),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    await _topicRepo.create(
      Topic(
        id: const Uuid().v4(),
        subjectId: widget.subjectId,
        name: name,
      ),
    );

    if (!mounted) return;

    _reload();
  }

  Future<void> _toggleTopic(Topic topic) async {
    await _topicRepo.setCompleted(
      topic.id,
      !topic.completed,
    );

    if (!mounted) return;

    _reload();
  }

  Future<void> _deleteTopic(Topic topic) async {
    await _topicRepo.delete(topic.id);

    if (!mounted) return;

    _reload();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Subject subject,
  ) async {
    final relatedCount =
        await _subjectRepo.countRelatedRecords(subject.id);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
          relatedCount > 0
              ? 'This will also delete $relatedCount related topic(s), session(s), and task(s). This cannot be undone.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _subjectRepo.delete(subject.id);

    if (!context.mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: AsyncBuilder<_DetailData>(
            future: _future,
            errorMessage: 'Could not load this subject.',
            onRetry: _reload,
            builder: (context, data) {
              final subject = data.subject;

              final completedTopics =
                  data.topics.where((t) => t.completed).length;

              final percent = data.topics.isEmpty
                  ? 0
                  : ((completedTopics / data.topics.length) * 100).round();

              final weekStart = startOfWeek(DateTime.now());
              final weekEnd = endOfWeek(DateTime.now());

              final thisWeekMinutes = data.sessions
                  .where(
                    (s) =>
                        s.complete &&
                        s.scheduledDate.isAfter(
                          weekStart.subtract(
                            const Duration(seconds: 1),
                          ),
                        ) &&
                        s.scheduledDate.isBefore(weekEnd),
                  )
                  .fold(
                    0,
                    (sum, s) => sum + (s.actualDuration ?? 0),
                  );

              final completedSessions =
                  data.sessions.where((s) => s.complete).toList();

              return Column(
                children: [
                  AppBar(
                    title: Text(subject.name),
                    leading: const BackButton(),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit subject',
                        onPressed: () async {
                          final changed =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => AddEditSubjectScreen(
                                existing: subject,
                              ),
                            ),
                          );

                          if (!mounted) return;

                          if (changed == true) {
                            _reload();
                          } else {
                            // Refresh anyway in case data changed
                            // through another route or process.
                            _reload();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete subject',
                        onPressed: () =>
                            _confirmDelete(context, subject),
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: context.cardSurface,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.card),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data.topics.length} topics • weekly target ${subject.weeklyTargetMinutes ~/ 60}h',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color:
                                            AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(
                                  height: AppSpacing.sm,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${formatDuration(thisWeekMinutes)} studied this week',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight:
                                                FontWeight.w500,
                                          ),
                                    ),
                                    Text(
                                      '$percent%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(
                                          subject.colorValue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: AppSpacing.lg,
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Topics',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                ),
                                tooltip: 'Add topic',
                                onPressed: () =>
                                    _addTopic(context),
                              ),
                            ],
                          ),
                          ...data.topics.map(
                            (topic) => TopicRow(
                              name: topic.name,
                              completed: topic.completed,
                              onChanged: (_) =>
                                  _toggleTopic(topic),
                              onDelete: () =>
                                  _deleteTopic(topic),
                            ),
                          ),
                          if (data.topics.isEmpty)
                            Text(
                              'No topics yet — add your first one above.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        AppColors.textSecondary,
                                  ),
                            ),
                          const SizedBox(
                            height: AppSpacing.lg,
                          ),
                          Text(
                            'Recent Sessions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          ...completedSessions.take(5).map(
                                (session) =>
                                    _RecentSessionRow(
                                  session: session,
                                ),
                              ),
                          if (completedSessions.isEmpty)
                            Text(
                              'No sessions recorded yet.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        AppColors.textSecondary,
                                  ),
                            ),
                          const SizedBox(
                            height: AppSpacing.lg,
                          ),
                          PrimaryButton(
                            label: 'Start Session',
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FocusTimerScreen(
                                    subjectId: subject.id,
                                    subjectName: subject.name,
                                    subjectColorValue:
                                        subject.colorValue,
                                  ),
                                ),
                              );

                              if (!mounted) return;

                              _reload();
                            },
                          ),
                          const SizedBox(
                            height: AppSpacing.lg,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailData {
  final Subject subject;
  final List<Topic> topics;
  final List<StudySession> sessions;

  const _DetailData({
    required this.subject,
    required this.topics,
    required this.sessions,
  });
}

class _RecentSessionRow extends StatelessWidget {
  final StudySession session;

  const _RecentSessionRow({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final weekday =
        _weekdayName(session.scheduledDate.weekday);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            weekday,
            style:
                Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            formatDuration(
              session.actualDuration ?? 0,
            ),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return names[weekday - 1];
  }
}