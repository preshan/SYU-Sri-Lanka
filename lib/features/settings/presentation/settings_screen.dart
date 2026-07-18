import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SyuGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined,
                  color: SyuColors.crimsonSoft),
              title: const Text('Notifications'),
              subtitle: const Text('In-app notification center'),
              onTap: () => context.push('/notifications'),
            ),
            const Divider(color: SyuColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset_rounded,
                  color: SyuColors.crimsonSoft),
              title: const Text('Reset password'),
              subtitle: const Text('Send a reset link to your email'),
              onTap: () => context.push('/forgot-password'),
            ),
            const Divider(color: SyuColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline,
                  color: SyuColors.crimsonSoft),
              title: const Text('About SYU Sri Lanka'),
              subtitle: const Text('Member app · Flutter + Supabase'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'SYU Sri Lanka',
                  applicationVersion: '0.2.0',
                  applicationLegalese: '© SYU Sri Lanka',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
