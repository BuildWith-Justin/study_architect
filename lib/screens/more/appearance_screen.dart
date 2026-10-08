import 'package:flutter/material.dart';

import '../../app/theme_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/gradient_background.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Appearance'),
                leading: const BackButton(),
              ),
              Expanded(
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, mode, _) {
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
                      ),
                      children: [
                        _ThemeOption(
                          mode: ThemeMode.system,
                          title: 'System',
                          subtitle: 'Follows your device setting',
                          selected: mode == ThemeMode.system,
                        ),
                        _ThemeOption(
                          mode: ThemeMode.light,
                          title: 'Light',
                          subtitle: 'Bright and clean',
                          selected: mode == ThemeMode.light,
                        ),
                        _ThemeOption(
                          mode: ThemeMode.dark,
                          title: 'Dark',
                          subtitle: 'Easier on the eyes at night',
                          selected: mode == ThemeMode.dark,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemeMode mode;
  final String title;
  final String subtitle;
  final bool selected;

  const _ThemeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  Widget _half(bool dark) {
    final bg = dark
        ? AppColors.darkBackgroundGradientTop
        : AppColors.backgroundGradientTop;
    final card = dark ? AppColors.surfaceDarkAlt : AppColors.surfaceLightAlt;
    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 8,
            width: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget preview = mode == ThemeMode.system
        ? Row(
            children: [
              Expanded(child: _half(false)),
              Expanded(child: _half(true)),
            ],
          )
        : _half(mode == ThemeMode.dark);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () => ThemeController.instance.setMode(mode),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    child: preview,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
