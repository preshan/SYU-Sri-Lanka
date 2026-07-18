import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/messaging/data/unread_chats_provider.dart';
import 'package:syu_sri_lanka/features/messaging/presentation/conversations_list_screen.dart';
import 'package:syu_sri_lanka/features/auth/data/auth_repository.dart';
import 'package:syu_sri_lanka/features/events/presentation/events_list_screen.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_overlay.dart';
import 'package:syu_sri_lanka/features/announcements/presentation/announcements_feed.dart';

/// Bump after registration/profile changes so Home/Profile CTAs refresh.
final profileStatusTickProvider = StateProvider<int>((ref) => 0);

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
    final hasUnreadChats = ref.watch(unreadChatsProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _HomeTab(email: email),
          const AnnouncementsFeed(),
          const EventsListScreen(),
          ConversationsListScreen(active: _index == 3),
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
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 3) {
            ref.read(unreadChatsProvider.notifier).refresh();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: SyuIcon(SyuIcons.home),
            selectedIcon: SyuIcon(SyuIcons.homeFilled),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: SyuIcon(SyuIcons.news),
            selectedIcon: SyuIcon(SyuIcons.news),
            label: 'News',
          ),
          const NavigationDestination(
            icon: SyuIcon(SyuIcons.calendar),
            selectedIcon: SyuIcon(SyuIcons.calendarCheck),
            label: 'Events',
          ),
          NavigationDestination(
            icon: SyuIcon(
              hasUnreadChats ? SyuIcons.chatUnread : SyuIcons.chat,
              color: hasUnreadChats ? SyuColors.crimson : null,
            ),
            selectedIcon: SyuIcon(
              hasUnreadChats ? SyuIcons.chatUnread : SyuIcons.chatAlt,
              color: hasUnreadChats ? SyuColors.crimson : null,
            ),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: SyuIcon(SyuIcons.user),
            selectedIcon: SyuIcon(SyuIcons.userCircle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab({required this.email});

  final String email;

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  String? _status;
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final user = SupabaseBootstrap.client.auth.currentUser;
      if (user == null) return;
      final row = await SupabaseBootstrap.client
          .from('profiles')
          .select('status')
          .eq('id', user.id)
          .maybeSingle();
      final admin = await SupabaseBootstrap.client.rpc('is_super_admin');
      if (!mounted) return;
      setState(() {
        _status = row?['status'] as String? ?? 'pending_registration';
        _isAdmin = admin == true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'pending_registration';
          _isAdmin = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _registrationIncomplete =>
      _status == null ||
      _status == 'pending_registration' ||
      _status == 'pending_approval';

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileStatusTickProvider, (_, _) {
      _loadStatus();
    });
    return SyuGradientBackground(
      child: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: SyuColors.crimson),
              )
            : _isAdmin
                ? _AdminHomeDashboard(email: widget.email)
                : _MemberHomeBody(
                    email: widget.email,
                    registrationIncomplete: _registrationIncomplete,
                  ),
      ),
    );
  }
}

class _MemberHomeBody extends StatelessWidget {
  const _MemberHomeBody({
    required this.email,
    required this.registrationIncomplete,
  });

  final String email;
  final bool registrationIncomplete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _HomeHeader(email: email),
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
        if (registrationIncomplete)
          const _ActionTile(
            icon: SyuIcons.userCheck,
            title: 'Complete registration',
            subtitle: 'Finish your member profile to activate membership.',
            onTapRoute: '/registration',
          )
        else
          const _ActionTile(
            icon: SyuIcons.userEdit,
            title: 'Update your details',
            subtitle: 'Keep your profile, contacts, and club info current.',
            onTapRoute: '/profile/edit',
          ),
        const SizedBox(height: 12),
        const _ActionTile(
          icon: SyuIcons.news,
          title: 'Latest announcements',
          subtitle: 'Open the News tab for updates.',
        ),
        const SizedBox(height: 12),
        const _ActionTile(
          icon: SyuIcons.calendarCheck,
          title: 'Upcoming events',
          subtitle: 'Browse and RSVP in the Events tab.',
        ),
        const SizedBox(height: 12),
        const _ActionTile(
          icon: SyuIcons.chat,
          title: 'Messages from SYU',
          subtitle: 'Open the Chat tab to read admin messages.',
        ),
      ],
    );
  }
}

class _AdminHomeDashboard extends StatelessWidget {
  const _AdminHomeDashboard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _HomeHeader(email: email),
        const SizedBox(height: 20),
        Text(
          'Admin dashboard',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: SyuColors.ink,
                fontSize: 40,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage members, publish news and events, and reach youth across districts.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: SyuColors.mist,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 24),
        Text('Members', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _AdminTileGrid(
          tiles: [
            _AdminSquareTile(
              icon: SyuIcons.people,
              title: 'Members',
              subtitle: 'Browse & message',
              adminTab: 'members',
            ),
            _AdminSquareTile(
              icon: SyuIcons.bookmarkOutline,
              title: 'Saved',
              subtitle: 'Quick shortlist',
              adminTab: 'members',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Quick access', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _AdminTileGrid(
          tiles: [
            _AdminChatSquareTile(),
            _AdminSquareTile(
              icon: SyuIcons.mail,
              title: 'Broadcast',
              subtitle: 'Notify audiences',
              adminTab: 'broadcast',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Publish', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _AdminTileGrid(
          tiles: [
            _AdminSquareTile(
              icon: SyuIcons.news,
              title: 'News',
              subtitle: 'Announcements',
              adminTab: 'news',
            ),
            _AdminSquareTile(
              icon: SyuIcons.calendar,
              title: 'Events',
              subtitle: 'Create & RSVP',
              adminTab: 'events',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Other tools', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _AdminTileGrid(
          tiles: [
            _AdminSquareTile(
              icon: SyuIcons.userGroup,
              title: 'Clubs',
              subtitle: 'Youth clubs',
              adminTab: 'clubs',
            ),
            _AdminSquareTile(
              icon: SyuIcons.chart,
              title: 'Reports',
              subtitle: 'Summaries',
              adminTab: 'reports',
            ),
            _AdminSquareTile(
              icon: SyuIcons.history,
              title: 'Audit',
              subtitle: 'Admin actions',
              adminTab: 'audit',
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminTileGrid extends StatelessWidget {
  const _AdminTileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                height: tileWidth,
                child: tile,
              ),
          ],
        );
      },
    );
  }
}

class _AdminChatSquareTile extends ConsumerWidget {
  const _AdminChatSquareTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(unreadChatsProvider);
    return _AdminSquareTile(
      icon: hasUnread ? SyuIcons.chatUnread : SyuIcons.chat,
      title: 'Chat',
      subtitle: hasUnread ? 'New messages' : 'Member threads',
      adminTab: 'chat',
      iconColor: hasUnread ? SyuColors.crimson : null,
    );
  }
}

class _AdminSquareTile extends StatelessWidget {
  const _AdminSquareTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.adminTab,
    this.iconColor,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final String adminTab;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openAdminOverlay(context, adminTab),
        child: Ink(
          decoration: BoxDecoration(
            color: SyuColors.inkElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SyuColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SyuColors.crimson.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SyuIcon(
                      icon,
                      color: iconColor ?? SyuIcons.accent,
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SyuColors.mist,
                        fontSize: 12,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/brand/syu_logo.png',
          height: 40,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
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

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final String? onTapRoute;

  @override
  Widget build(BuildContext context) {
    final tappable = onTapRoute != null;
    final child = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SyuColors.inkElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SyuColors.border),
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
            child: Center(
              child: SyuIcon(icon, color: SyuIcons.accent, size: 24),
            ),
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
          if (tappable)
            const SyuIcon(SyuIcons.chevronRight, color: SyuColors.mist),
        ],
      ),
    );

    if (!tappable) return child;
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
        'pending_approval' => 'Pending (legacy)',
        'active' => 'Active member',
        'suspended' => 'Suspended',
        _ => _status ?? 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileStatusTickProvider, (_, _) {
      _load();
    });
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
                    border: Border.all(color: SyuColors.border),
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
                icon: const SyuIcon(SyuIcons.edit, size: 20),
                label: Text(
                  _status == 'pending_registration'
                      ? 'Edit profile'
                      : 'Update your details',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const SyuIcon(SyuIcons.settings, size: 20),
                label: const Text('Settings'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openAdminOverlay(context, 'members'),
                child: const Text('Admin console'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const SyuIcon(SyuIcons.logout, size: 20),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
