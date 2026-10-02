import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
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
import '../../widgets/roadmap_topic_tile.dart';
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
    with WidgetsBindingObserver, RefreshableScreenMixin {
  final _subjectRepo = SubjectRepository();
  final _topicRepo = TopicRepository();
  final _sessionRepo = SessionRepository();

  late Future<_DetailData> _future;

  /// Topic ids in the order the person just dragged them to. Shown
  /// immediately so the list does not jump back while the new order is
  /// being saved; cleared once the reload from the database is done.
  List<String>? _pendingOrder;

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

  /// Called by RefreshableScreenMixin when sync brings in cloud changes.
  @override
  Future<void> onRefresh() => _refresh();

  /// Tells the other screens (for example the Subjects list underneath
  /// this one) that subject or topic data changed.
  void _notifyChanged() {
    DataRefreshBus.instance.notify(RefreshScope.all);
  }

  /// Applies the not-yet-saved drag order on top of the loaded topics.
  List<Topic> _ordered(List<Topic> topics) {
    final pending = _pendingOrder;
    if (pending == null) return topics;

    final byId = {for (final t in topics) t.id: t};
    final result = <Topic>[];
    for (final id in pending) {
      final topic = byId.remove(id);
      if (topic != null) result.add(topic);
    }
    result.addAll(byId.values);
    return result;
  }

  // --------------------------------------------------------------- topics

  /// Asks for a topic name. Returns null if cancelled.
  Future<String?> _promptTopicName({
    required String title,
    required String confirmLabel,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initial.length,
    );

    TransitionRoute<dynamic>? dialogRoute;

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of(dialogContext);

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Differential Equations',
            ),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    // Wait until the dialog route has completely finished
    // its exit transition and has been removed from the overlay.
    if (dialogRoute != null) {
      await dialogRoute!.completed;
    }

    controller.dispose();

    return name;
  }

  Future<void> _addTopic() async {
    final name = await _promptTopicName(
      title: 'New topic',
      confirmLabel: 'Add',
    );

    if (name == null || name.isEmpty) return;

    await _topicRepo.create(
      Topic(
        id: const Uuid().v4(),
        subjectId: widget.subjectId,
        name: name,
      ),
    );

    if (!mounted) return;

    await _refresh();
    _notifyChanged();
  }

  Future<void> _renameTopic(Topic topic) async {
    final name = await _promptTopicName(
      title: 'Rename topic',
      confirmLabel: 'Save',
      initial: topic.name,
    );

    if (name == null || name.isEmpty || name == topic.name) return;

    await _topicRepo.rename(topic.id, name);

    if (!mounted) return;

    await _refresh();
    _notifyChanged();
  }

  Future<void> _toggleTopic(Topic topic) async {
    await _topicRepo.setCompleted(
      topic.id,
      !topic.completed,
    );

    if (!mounted) return;

    await _refresh();
    _notifyChanged();
  }

  Future<void> _deleteTopic(Topic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete topic?'),
        content: Text(
          '"${topic.name}" will be removed from the roadmap. '
          'Sessions and tasks linked to it are kept but unlinked.',
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

    await _topicRepo.delete(topic.id);

    if (!mounted) return;

    await _refresh();
    _notifyChanged();
  }

  Future<void> _onReorder(
    List<Topic> current,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;

    final ids = current.map((t) => t.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);

    // 1) Instant feedback on screen.
    setState(() {
      _pendingOrder = ids;
    });

    // 2) Save to the database.
    try {
      await _topicRepo.reorder(ids);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingOrder = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the new order.')),
      );
      return;
    }

    if (!mounted) return;

    // 3) Reload from the database, then drop the temporary order.
    await _refresh();

    if (!mounted) return;

    setState(() {
      _pendingOrder = null;
    });
    _notifyChanged();
  }

  // -------------------------------------------------------------- subject

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

  // ------------------------------------------------------------ UI pieces

  Widget _summaryCard(
    BuildContext context, {
    required Subject subject,
    required Color accent,
    required int topicCount,
    required int completedTopics,
    required int percent,
    required int thisWeekMinutes,
  }) {
    final theme = Theme.of(context);
    final targetMinutes = subject.weeklyTargetMinutes;
    final weekProgress = targetMinutes <= 0
        ? 0.0
        : (thisWeekMinutes / targetMinutes).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Roadmap progress',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: topicCount == 0 ? 0 : percent / 100,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$completedTopics of $topicCount topics done',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This week',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${formatDuration(thisWeekMinutes)} of ${targetMinutes ~/ 60}h',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: weekProgress,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roadmapSection(
    BuildContext context, {
    required List<Topic> topics,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final nextIndex = topics.indexWhere((t) => !t.completed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study roadmap',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (topics.length > 1)
                    Text(
                      'Drag the handle to reorder  ·  tap a topic to rename',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'Add topic',
              onPressed: _addTopic,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (topics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.cardSurfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.cardSmall),
            ),
            child: Text(
              'No topics yet — tap + to add the first step of your roadmap.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: topics.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(topics, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final topic = topics[index];

              return RoadmapTopicTile(
                key: ValueKey(topic.id),
                index: index,
                name: topic.name,
                completed: topic.completed,
                isNext: index == nextIndex,
                accent: accent,
                onChanged: (_) => _toggleTopic(topic),
                onTap: () => _renameTopic(topic),
                onDelete: () => _deleteTopic(topic),
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- build

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
              final accent = Color(subject.colorValue);
              final topics = _ordered(data.topics);

              final completedTopics =
                  topics.where((t) => t.completed).length;

              final percent = topics.isEmpty
                  ? 0
                  : ((completedTopics / topics.length) * 100).round();

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
                  .fold<int>(
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
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => AddEditSubjectScreen(
                                existing: subject,
                              ),
                            ),
                          );

                          if (!mounted) return;

                          // Refresh whether or not something was saved,
                          // in case data changed through another route.
                          await _refresh();
                          _notifyChanged();
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
                          _summaryCard(
                            context,
                            subject: subject,
                            accent: accent,
                            topicCount: topics.length,
                            completedTopics: completedTopics,
                            percent: percent,
                            thisWeekMinutes: thisWeekMinutes,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _roadmapSection(
                            context,
                            topics: topics,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Recent Sessions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          ...completedSessions.take(5).map(
                                (session) => _RecentSessionRow(
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
                                    color: context.secondaryText,
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
                                  builder: (_) => FocusTimerScreen(
                                    subjectId: subject.id,
                                    subjectName: subject.name,
                                    subjectColorValue: subject.colorValue,
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
    final weekday = _weekdayName(session.scheduledDate.weekday);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            weekday,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            formatDuration(
              session.actualDuration ?? 0,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.secondaryText,
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
