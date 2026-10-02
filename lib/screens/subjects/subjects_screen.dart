import 'package:flutter/material.dart';
import '../../core/refreshable_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/subject_list_tile.dart';
import 'add_edit_subject_screen.dart';
import 'subject_detail_screen.dart';
import 'subjects_view_data.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with WidgetsBindingObserver, RefreshableScreenMixin {
  late Future<List<SubjectSummary>> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = SubjectSummary.loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final future = SubjectSummary.loadAll();

    if (!mounted) return;

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // The FutureBuilder displays the error state.
    }
  }

  /// Called by RefreshableScreenMixin when sync brings in cloud changes.
  @override
  Future<void> onRefresh() => _reload();

  Future<void> _openAdd() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddEditSubjectScreen(),
      ),
    );

    if (!mounted) return;

    await _reload();
  }

  Future<void> _openDetail(String subjectId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubjectDetailScreen(
          subjectId: subjectId,
        ),
      ),
    );

    if (!mounted) return;

    if (changed == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SubjectSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
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
                    'Could not load subjects.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Please try again.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.secondaryText,
                        ),
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

        final summaries = snapshot.data ?? [];
        final countLabel = summaries.length == 1
            ? '1 active subject'
            : '${summaries.length} active subjects';

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subjects',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        countLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.secondaryText,
                            ),
                      ),
                    ],
                  ),
                  IconButton.filled(
                    onPressed: _openAdd,
                    tooltip: 'Add subject',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: summaries.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 40,
                                      color: context.secondaryText,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'No subjects yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Add your first subject to start planning.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: context.secondaryText,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    SizedBox(
                                      width: 220,
                                      child: PrimaryButton(
                                        label: 'Add subject',
                                        icon: Icons.add_rounded,
                                        onPressed: _openAdd,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: summaries.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final summary = summaries[index];

                            return SubjectListTile(
                              name: summary.subject.name,
                              topicCount: summary.topicCount,
                              completionPercent: summary.completionPercent,
                              weeklyTargetMinutes:
                                  summary.subject.weeklyTargetMinutes,
                              accent: Color(summary.subject.colorValue),
                              onTap: () => _openDetail(summary.subject.id),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
