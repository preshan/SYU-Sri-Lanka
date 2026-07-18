import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/app_info.dart';
import 'package:syu_sri_lanka/core/permissions/app_permissions.dart';
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

/// Bump after registration/profile changes so Home/Settings CTAs refresh.
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
          _SettingsTab(
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
            icon: SyuIcon(SyuIcons.settings),
            selectedIcon: SyuIcon(SyuIcons.settings),
            label: 'Settings',
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: SyuColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage members, publish news and events, and reach youth across districts.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SyuColors.mist,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 18),
        Text('Members', style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text('Quick access', style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text('Publish', style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text('Other tools', style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
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

TextStyle? _adminSectionTitle(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.2,
          color: SyuColors.mist,
        );

class _AdminTileGrid extends StatelessWidget {
  const _AdminTileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => openAdminOverlay(context, adminTab),
        child: Ink(
          decoration: BoxDecoration(
            color: SyuColors.inkElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SyuColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: SyuColors.crimson.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: SyuIcon(
                          icon,
                          color: iconColor ?? SyuIcons.accent,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.15,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SyuColors.mist,
                        fontSize: 11,
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

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({required this.email, required this.onSignOut});

  final String email;
  final VoidCallback onSignOut;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
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
      // Soft-fail: settings still shows email + sign out.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLink(String url) async {
    final ok = await AppPermissions.openLink(url);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open link')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileStatusTickProvider, (_, _) {
      _load();
    });
    final mistStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SyuColors.mist,
          fontSize: 11,
          height: 1.35,
        );
    final buttonGap = const SizedBox(height: 8);
    return SyuGradientBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _fullName?.isNotEmpty == true ? _fullName! : widget.email,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_fullName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(color: SyuColors.crimson),
              ],
              if (_status == 'pending_registration') ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/registration'),
                  child: const Text('Complete registration'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const SyuIcon(SyuIcons.edit, size: 20),
                label: Text(
                  _status == 'pending_registration'
                      ? 'Edit profile'
                      : 'Update your details',
                ),
              ),
              buttonGap,
              OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const SyuIcon(SyuIcons.notification, size: 20),
                label: const Text('Notifications & account'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SyuColors.crimson,
                  side: const BorderSide(color: SyuColors.crimson),
                  iconColor: SyuColors.crimson,
                ),
                onPressed: widget.onSignOut,
                icon: const SyuIcon(
                  SyuIcons.logout,
                  size: 20,
                  color: SyuColors.crimson,
                ),
                label: const Text('Sign out'),
              ),
              const Spacer(),
              Text(
                'App version ${AppInfo.versionLabel}',
                textAlign: TextAlign.center,
                style: mistStyle,
              ),
              const SizedBox(height: 2),
              Text(
                AppInfo.copyright,
                textAlign: TextAlign.center,
                style: mistStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Developed by ${AppInfo.developerName}',
                textAlign: TextAlign.center,
                style: mistStyle,
              ),
              const SizedBox(height: 2),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: mistStyle?.copyWith(
                        decoration: TextDecoration.underline,
                        color: SyuColors.crimson,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: () => _openLink(AppInfo.developerLinkedIn),
                    child: const Text('LinkedIn'),
                  ),
                  Text('·', style: mistStyle),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: mistStyle?.copyWith(
                        decoration: TextDecoration.underline,
                        color: SyuColors.crimson,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: () =>
                        _openLink('mailto:${AppInfo.developerEmail}'),
                    child: Text(AppInfo.developerEmail),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
