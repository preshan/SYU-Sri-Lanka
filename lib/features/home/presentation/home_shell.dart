import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/features/announcements/presentation/announcements_feed.dart';
import 'package:syu_sri_lanka/features/auth/data/auth_repository.dart';
import 'package:syu_sri_lanka/features/events/presentation/events_list_screen.dart';
import 'package:syu_sri_lanka/features/messaging/presentation/conversations_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? 'Member';

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _HomeTab(email: email),
          const AnnouncementsFeed(),
          const EventsListScreen(),
          const ConversationsListScreen(),
          _ProfileTab(
            email: email,
            onSignOut: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return SyuGradientBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                Image.asset('assets/brand/syu_logo_128.png', height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYU Sri Lanka',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Rise together.',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: SyuColors.crimson,
                    fontSize: 48,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your hub for membership, announcements, events, and club messaging.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SyuColors.mist,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 28),
            const _ActionTile(
              icon: Icons.how_to_reg_outlined,
              title: 'Complete registration',
              subtitle: 'Finish your member profile for approval.',
              onTapRoute: '/registration',
            ),
            const SizedBox(height: 12),
            const _ActionTile(
              icon: Icons.campaign_outlined,
              title: 'Latest announcements',
              subtitle: 'Open the News tab for updates.',
            ),
            const SizedBox(height: 12),
            const _ActionTile(
              icon: Icons.event_available_outlined,
              title: 'Upcoming events',
              subtitle: 'Browse and RSVP in the Events tab.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTapRoute,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? onTapRoute;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SyuColors.inkElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SyuColors.crimson.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SyuColors.crimsonSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (onTapRoute != null)
            const Icon(Icons.chevron_right_rounded, color: SyuColors.mist),
        ],
      ),
    );

    if (onTapRoute == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(onTapRoute!),
        child: child,
      ),
    );
  }
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab({required this.email, required this.onSignOut});

  final String email;
  final VoidCallback onSignOut;

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  String? _status;
  String? _fullName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = SupabaseBootstrap.client.auth.currentUser;
      if (user == null) return;
      final row = await SupabaseBootstrap.client
          .from('profiles')
          .select('full_name,status')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _fullName = row?['full_name'] as String?;
        _status = row?['status'] as String? ?? 'pending_registration';
      });
    } catch (_) {
      // Soft-fail: profile tab still shows email + sign out.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _statusLabel => switch (_status) {
        'pending_registration' => 'Registration incomplete',
        'pending_approval' => 'Pending admin approval',
        'active' => 'Active member',
        'suspended' => 'Suspended',
        _ => _status ?? 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    return SyuGradientBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                _fullName?.isNotEmpty == true ? _fullName! : widget.email,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_fullName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(widget.email, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const LinearProgressIndicator(color: SyuColors.crimson)
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SyuColors.inkElevated.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (_status == 'pending_registration') ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/registration'),
                  child: const Text('Complete registration'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Settings'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/admin'),
                child: const Text('Admin console'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
