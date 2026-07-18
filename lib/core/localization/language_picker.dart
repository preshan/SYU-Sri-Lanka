import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/localization/locale_provider.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// Compact NAITA-style switcher: En | සිං | த
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({
    super.key,
    this.isCompact = false,
    this.onLightBackground = true,
  });

  /// When true, shows the short En | සිං | த pill (also used on dashboard).
  final bool isCompact;

  /// White pill on light UI; when false, white pill suited for crimson headers.
  final bool onLightBackground;

  static const _options = <(Locale, String)>[
    (Locale('en'), 'En'),
    (Locale('si'), 'සිං'),
    (Locale('ta'), 'த'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = Locale(ref.watch(localeProvider).languageCode);

    if (isCompact) {
      return _LanguagePill(
        current: currentLocale,
        onLightBackground: onLightBackground,
        onSelected: (locale) =>
            ref.read(localeProvider.notifier).setLocale(locale),
      );
    }

    return SegmentedButton<Locale>(
      segments: const [
        ButtonSegment(value: Locale('en'), label: Text('English')),
        ButtonSegment(value: Locale('si'), label: Text('සිංහල')),
        ButtonSegment(value: Locale('ta'), label: Text('தமிழ்')),
      ],
      selected: {currentLocale},
      onSelectionChanged: (set) =>
          ref.read(localeProvider.notifier).setLocale(set.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: SyuColors.crimson,
        selectedForegroundColor: SyuColors.paper,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.current,
    required this.onSelected,
    required this.onLightBackground,
  });

  final Locale current;
  final ValueChanged<Locale> onSelected;
  final bool onLightBackground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: onLightBackground ? 0 : 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: onLightBackground
              ? Border.all(color: SyuColors.border)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < LanguagePicker._options.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: SyuColors.ink.withValues(alpha: 0.35),
                ),
              _LangOption(
                label: LanguagePicker._options[i].$2,
                selected: current.languageCode ==
                    LanguagePicker._options[i].$1.languageCode,
                onTap: () => onSelected(LanguagePicker._options[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 1.1,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? SyuColors.crimson : SyuColors.ink,
          ),
        ),
      ),
    );
  }
}
