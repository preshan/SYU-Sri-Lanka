import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';

/// Compact chrome for admin tool panels.
/// Page title lives in [AdminShell] AppBar only — do not repeat it here.
abstract final class AdminPanelChrome {
  static const edgeInsets = EdgeInsets.fromLTRB(10, 2, 10, 0);
  static const listPadding = EdgeInsets.fromLTRB(10, 0, 2, 4);
  static const pageSize = 40;

  static TextStyle? hintStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SyuColors.mist,
            fontSize: 12,
            height: 1.2,
          );

  static TextStyle? rowTitleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.1,
          );

  static TextStyle? rowMetaStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SyuColors.mist,
            fontSize: 11,
            height: 1.25,
          );

  /// Top strip: optional one-line hint + primary actions (no page title).
  static Widget toolbar({
    required BuildContext context,
    String? hint,
    List<Widget> actions = const [],
  }) {
    return Padding(
      padding: edgeInsets,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hint != null && hint.isNotEmpty)
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hintStyle(context),
              ),
            )
          else
            const Spacer(),
          for (final w in actions)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: w,
            ),
        ],
      ),
    );
  }

  static ButtonStyle get compactFilled => FilledButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      );

  static Widget denseDivider() => const Divider(
        height: 1,
        thickness: 1,
        color: SyuColors.border,
      );

  static int totalPages(int total, [int size = pageSize]) =>
      total == 0 ? 1 : ((total + size - 1) / size).floor();
}

/// Shared bottom pager for admin lists.
class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = total == 0 ? 0 : ((page + 1) * pageSize).clamp(0, total);
    return Material(
      color: SyuColors.inkElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              Text(
                '$from–$to of $total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: SyuColors.mist,
                    ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onPrev,
                icon: const SyuIcon(SyuIcons.chevronLeft, size: 18),
                tooltip: 'Previous page',
              ),
              Text(
                '${page + 1} / $totalPages',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                    ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onNext,
                icon: const SyuIcon(SyuIcons.chevronRight, size: 18),
                tooltip: 'Next page',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
