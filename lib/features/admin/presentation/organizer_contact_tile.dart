import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/permissions/app_permissions.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/utils/syu_phone_links.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Shared organizer contact layout:
/// name | dn
/// mobile: … [call] [whatsapp]
/// landline: … [call]
/// email (mailto)
class OrganizerContactTile extends StatelessWidget {
  const OrganizerContactTile({
    super.key,
    required this.fullName,
    required this.dsName,
    required this.mobile,
    this.landline,
    this.email,
    this.onEdit,
    this.dense = false,
  });

  final String fullName;
  final String dsName;
  final String mobile;
  final String? landline;
  final String? email;
  final VoidCallback? onEdit;
  final bool dense;

  Future<void> _open(BuildContext context, String? url) async {
    if (url == null) return;
    final ok = await AppPermissions.openLink(url);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).couldNotOpenLink)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final land = landline?.trim() ?? '';
    final mail = email?.trim() ?? '';
    final titleLine =
        dsName.trim().isEmpty ? fullName : '$fullName | $dsName';

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 8 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleLine,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 13 : 14,
                  ),
                ),
                if (mobile.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _inlineContactRow(
                    context,
                    label: '${l10n.mobile}: $mobile',
                    onLabelTap: () =>
                        _open(context, SyuPhoneLinks.telUrl(mobile)),
                    trailing: [
                      _iconBtn(
                        tooltip: 'Call $mobile',
                        icon: SyuIcons.phone,
                        color: SyuColors.crimson,
                        onPressed: () =>
                            _open(context, SyuPhoneLinks.telUrl(mobile)),
                      ),
                      _iconBtn(
                        tooltip: 'WhatsApp $mobile',
                        icon: SyuIcons.whatsapp,
                        color: SyuIcons.whatsappGreen,
                        onPressed: () =>
                            _open(context, SyuPhoneLinks.whatsappUrl(mobile)),
                      ),
                    ],
                  ),
                ],
                if (land.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _inlineContactRow(
                    context,
                    label: '${l10n.landline}: $land',
                    onLabelTap: () =>
                        _open(context, SyuPhoneLinks.telUrl(land)),
                    trailing: [
                      _iconBtn(
                        tooltip: 'Call $land',
                        icon: SyuIcons.phone,
                        color: SyuColors.crimson,
                        onPressed: () =>
                            _open(context, SyuPhoneLinks.telUrl(land)),
                      ),
                    ],
                  ),
                ],
                if (mail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () =>
                        _open(context, SyuPhoneLinks.mailtoUrl(mail)),
                    child: Text(
                      mail,
                      style: textTheme.bodySmall?.copyWith(
                        color: SyuColors.crimson,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: SyuColors.crimson,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: l10n.editOrganizer,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const SyuIcon(
                SyuIcons.edit,
                size: 18,
                color: SyuColors.crimson,
              ),
            ),
        ],
      ),
    );
  }

  Widget _inlineContactRow(
    BuildContext context, {
    required String label,
    required VoidCallback onLabelTap,
    required List<Widget> trailing,
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        GestureDetector(
          onTap: onLabelTap,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SyuColors.crimson,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: SyuColors.crimson,
                ),
          ),
        ),
        ...trailing,
      ],
    );
  }

  Widget _iconBtn({
    required String tooltip,
    required List<List<dynamic>> icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        icon: SyuIcon(icon, size: 18, color: color),
        onPressed: onPressed,
      ),
    );
  }
}
