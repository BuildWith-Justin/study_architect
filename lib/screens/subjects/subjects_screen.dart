import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/subject_card.dart';
import '../../widgets/pastel_card.dart';
import 'subjects_view_data.dart';
import 'add_edit_subject_screen.dart';
import 'subject_detail_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with WidgetsBindingObserver {
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

  PastelHue _hueFor(int colorValue) {
    if (colorValue == AppColors.accentGreenStrong.toARGB32()) {
      return PastelHue.green;
    }

    if (colorValue == AppColors.accentBlueStrong.toARGB32()) {
      return PastelHue.blue;
    }

    return PastelHue.purple;
  }

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
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
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
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final summaries = snapshot.data ?? [];

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
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${summaries.length} active subjects',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      size: 28,
                    ),
                    onPressed: _openAdd,
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
                              height:
                                  MediaQuery.of(context).size.height * 0.55,
                              child: Center(
                                child: Text(
                                  'No subjects yet — tap + to add one.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: summaries.length,
                          separatorBuilder: (_, __) => const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          itemBuilder: (context, index) {
                            final summary = summaries[index];

                            return SubjectCard(
                              name: summary.subject.name,
                              topicCount: summary.topicCount,
                              completionPercent: summary.completionPercent,
                              hue: _hueFor(
                                summary.subject.colorValue,
                              ),
                              onTap: () => _openDetail(
                                summary.subject.id,
                              ),
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