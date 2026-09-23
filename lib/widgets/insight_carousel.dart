import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';
import '../utils/study_insights.dart';

/// Horizontal swipeable carousel for the Progress screen's Insights
/// section — one insight per page, with dot indicators below.
/// Replaces the old vertical stack of cards.
class InsightCarousel extends StatefulWidget {
  final List<StudyInsight> insights;

  const InsightCarousel({super.key, required this.insights});

  @override
  State<InsightCarousel> createState() => _InsightCarouselState();
}

class _InsightCarouselState extends State<InsightCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.insights.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final insight = widget.insights[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(insight.icon, size: 20, color: AppColors.accentPurpleStrong),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          insight.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.primaryText,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.insights.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.insights.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accentPurpleStrong
                      : AppColors.accentPurpleStrong.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}