import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/app_info.dart';
import 'package:syu_sri_lanka/core/config/app_config.dart';
import 'package:syu_sri_lanka/core/localization/language_picker.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/permissions/app_permissions.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notificationsOn;
  String _websiteUrl = AppConfig.defaultWebsiteUrl;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
    _loadWebsiteUrl();
  }

  Future<void> _refreshPermission() async {
    final on = await AppPermissions.notificationsGranted;
    if (mounted) setState(() => _notificationsOn = on);
  }

  Future<void> _loadWebsiteUrl() async {
    final url = await AppConfig.websiteUrl();
    if (mounted) setState(() => _websiteUrl = url);
  }

  Future<void> _enableNotifications() async {
    await AppPermissions.requestNotificationsOrOpenSettings();
    await _refreshPermission();
  }

  String get _websiteHostLabel {
    final uri = Uri.tryParse(_websiteUrl);
    if (uri == null || uri.host.isEmpty) return _websiteUrl;
    return uri.host;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SyuBackScope(
      fallbackLocation: '/home',
      child: SyuGradientBackground(
        child: Scaffold(
          backgroundColor: SyuColors.paper,
          appBar: AppBar(
            title: Text(l10n.settings),
            leading: IconButton(
              icon: const SyuIcon(SyuIcons.back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l10n.language,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const LanguagePicker(),
              const SizedBox(height: 24),
              Text('Account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SyuIcon(SyuIcons.notification,
                    color: SyuColors.crimsonSoft),
                title: Text(l10n.notifications),
                subtitle:
                    const Text('Messages, news, and event alerts in the app'),
                onTap: () => context.push('/notifications'),
              ),
              const Divider(color: SyuColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SyuIcon(SyuIcons.notification,
                    color: SyuColors.crimsonSoft),
                title: const Text('Allow notifications'),
                subtitle: Text(
                  _notificationsOn == null
                      ? 'Checking…'
                      : _notificationsOn!
                          ? 'Enabled on this device'
                          : 'Tap to allow alerts (required on Android 13+)',
                ),
                trailing: _notificationsOn == true
                    ? const SyuIcon(SyuIcons.verified,
                        size: 20, color: SyuColors.success)
                    : null,
                onTap: _enableNotifications,
              ),
              const Divider(color: SyuColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SyuIcon(SyuIcons.resetPassword,
                    color: SyuColors.crimsonSoft),
                title: Text(l10n.forgotPassword.replaceAll('?', '')),
                subtitle: const Text('Send a reset link to your email'),
                onTap: () => context.push('/forgot-password'),
              ),
              const Divider(color: SyuColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SyuIcon(SyuIcons.info,
                    color: SyuColors.crimsonSoft),
                title: const Text('SYU website'),
                subtitle: Text('Open $_websiteHostLabel in your browser'),
                onTap: () async {
                  final ok = await AppPermissions.openHttps(_websiteUrl);
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open link')),
                    );
                  }
                },
              ),
              const Divider(color: SyuColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SyuIcon(SyuIcons.info,
                    color: SyuColors.crimsonSoft),
                title: const Text('About SYU Sri Lanka'),
                subtitle: const Text('Member app · Flutter + Supabase'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: AppInfo.name,
                    applicationVersion: AppInfo.versionLabel,
                    applicationLegalese: '© SYU Sri Lanka',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
