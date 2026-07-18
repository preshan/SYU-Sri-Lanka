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
import 'package:syu_sri_lanka/features/admin/presentation/admin_chat_panel.dart';
import 'package:syu_sri_lanka/core/localization/language_picker.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_overlay.dart';
import 'package:syu_sri_lanka/features/announcements/presentation/announcements_feed.dart';
import 'package:syu_sri_lanka/features/profile/domain/profile_completeness.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Bump after registration/profile changes so Home/Settings CTAs refresh.
final profileStatusTickProvider = StateProvider<int>((ref) => 0);

/// Increment to switch [HomeShell] to the Chat bottom tab (admin quick access).
final openHomeChatTabProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _chatIndex = 3;
  static const _homeIndex = 0;

  final _memberChatKey = GlobalKey<ConversationsListScreenState>();
  final _adminChatKey = GlobalKey<AdminChatPanelState>();

  int _index = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    try {
      final admin = await SupabaseBootstrap.client.rpc('is_super_admin');
      if (mounted) setState(() => _isAdmin = admin == true);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  bool get _chatThreadOpen {
    if (_isAdmin) {
      return _adminChatKey.currentState?.hasOpenThread ?? false;
    }
    return _memberChatKey.currentState?.hasOpenThread ?? false;
  }

  bool _closeChatThreadIfOpen() {
    if (_isAdmin) {
      return _adminChatKey.currentState?.handleSystemBack() ?? false;
    }
    return _memberChatKey.currentState?.handleSystemBack() ?? false;
  }

  /// Android/iOS system back: close chat → Home tab → then allow exit.
  void _onSystemBack() {
    if (_closeChatThreadIfOpen()) {
      setState(() {}); // refresh canPop after thread closes
      return;
    }
    if (_index != _homeIndex) {
      setState(() => _index = _homeIndex);
    }
  }

  Widget _chatTab() {
    if (_isAdmin) {
      return SyuGradientBackground(
        child: SafeArea(
          child: AdminChatPanel(
            key: _adminChatKey,
            embedded: true,
          ),
        ),
      );
    }
    return ConversationsListScreen(
      key: _memberChatKey,
      active: _index == _chatIndex,
      embedInHomeShell: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? 'Member';
    final hasUnread = ref.watch(unreadChatsProvider);
    final chatIcon = hasUnread ? SyuIcons.chatUnread : SyuIcons.chat;
    final chatIconColor = hasUnread ? SyuColors.crimson : null;
    final l10n = AppLocalizations.of(context);

    ref.listen<int>(openHomeChatTabProvider, (_, _) {
      setState(() => _index = _chatIndex);
    });

    // Allow OS minimize/exit only on Home with no open chat thread.
    final allowExit = _index == _homeIndex && !_chatThreadOpen;

    return PopScope(
      canPop: allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onSystemBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _HomeTab(email: email),
            const AnnouncementsFeed(),
            const EventsListScreen(),
            _chatTab(),
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
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const SyuIcon(SyuIcons.home),
              selectedIcon: const SyuIcon(SyuIcons.homeFilled),
              label: l10n.home,
            ),
            NavigationDestination(
              icon: const SyuIcon(SyuIcons.news),
              selectedIcon: const SyuIcon(SyuIcons.news),
              label: l10n.news,
            ),
            NavigationDestination(
              icon: const SyuIcon(SyuIcons.calendar),
              selectedIcon: const SyuIcon(SyuIcons.calendarCheck),
              label: l10n.events,
            ),
            NavigationDestination(
              icon: SyuIcon(chatIcon, color: chatIconColor),
              selectedIcon: SyuIcon(chatIcon, color: chatIconColor),
              label: l10n.chat,
            ),
            NavigationDestination(
              icon: const SyuIcon(SyuIcons.settings),
              selectedIcon: const SyuIcon(SyuIcons.settings),
              label: l10n.settings,
            ),
          ],
        ),
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
  bool _registrationIncomplete = true;
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
          .select(
            'status,full_name,phone,nic,date_of_birth,district_id',
          )
          .eq('id', user.id)
          .maybeSingle();
      final admin = await SupabaseBootstrap.client.rpc('is_super_admin');
      if (!mounted) return;
      final status = row?['status'] as String? ?? 'active';
      final completeness = ProfileCompleteness.fromProfile(row);
      setState(() {
        _registrationIncomplete = completeness.missingKeys.isNotEmpty ||
            status == 'pending_registration' ||
            status == 'pending_approval';
        _isAdmin = admin == true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _registrationIncomplete = true;
          _isAdmin = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _HomeHeader(email: email),
        const SizedBox(height: 28),
        Text(
          l10n.riseTogether,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: SyuColors.crimson,
                fontSize: 48,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.hubSubtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: SyuColors.mist,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 28),
        if (registrationIncomplete)
          _ActionTile(
            icon: SyuIcons.userCheck,
            title: l10n.completeRegistration,
            subtitle: l10n.completeRegistrationSubtitle,
            onTapRoute: '/registration',
          )
        else
          _ActionTile(
            icon: SyuIcons.userEdit,
            title: l10n.updateDetails,
            subtitle: l10n.updateDetailsSubtitle,
            onTapRoute: '/profile/edit',
          ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: SyuIcons.news,
          title: l10n.latestAnnouncements,
          subtitle: l10n.newsSubtitle,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: SyuIcons.calendarCheck,
          title: l10n.upcomingEvents,
          subtitle: l10n.eventsSubtitle,
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
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _HomeHeader(email: email),
        const SizedBox(height: 20),
        Text(
          l10n.adminDashboard,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: SyuColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.adminDashboardSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SyuColors.mist,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 18),
        Text(l10n.members, style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
        _AdminTileGrid(
          tiles: [
            _AdminSquareTile(
              icon: SyuIcons.people,
              title: l10n.members,
              subtitle: l10n.browseAndMessage,
              adminTab: 'members',
            ),
            _AdminSquareTile(
              icon: SyuIcons.bookmarkOutline,
              title: l10n.saved,
              subtitle: l10n.quickShortlist,
              adminTab: 'members',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.quickAccess, style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
        _AdminTileGrid(
          tiles: [
            const _AdminChatSquareTile(),
            _AdminSquareTile(
              icon: SyuIcons.mail,
              title: l10n.broadcast,
              subtitle: l10n.notifyAudiences,
              adminTab: 'broadcast',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.publish, style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
        _AdminTileGrid(
          tiles: [
            _AdminSquareTile(
              icon: SyuIcons.news,
              title: l10n.news,
              subtitle: l10n.announcements,
              adminTab: 'news',
            ),
            _AdminSquareTile(
              icon: SyuIcons.calendar,
              title: l10n.events,
              subtitle: l10n.createAndRsvp,
              adminTab: 'events',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.otherTools, style: _adminSectionTitle(context)),
        const SizedBox(height: 8),
        _AdminTileGrid(
          tiles: [
            _AdminSquareTile(
              icon: SyuIcons.userGroup,
              title: l10n.clubs,
              subtitle: l10n.youthClubs,
              adminTab: 'clubs',
            ),
            _AdminSquareTile(
              icon: SyuIcons.chart,
              title: l10n.reports,
              subtitle: l10n.summaries,
              adminTab: 'reports',
            ),
            _AdminSquareTile(
              icon: SyuIcons.history,
              title: l10n.audit,
              subtitle: l10n.adminActions,
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
    final l10n = AppLocalizations.of(context);
    return _AdminSquareTile(
      icon: hasUnread ? SyuIcons.chatUnread : SyuIcons.chat,
      title: l10n.chat,
      subtitle: hasUnread ? l10n.newMessages : l10n.memberThreads,
      iconColor: hasUnread ? SyuColors.crimson : null,
      onTap: () {
        ref.read(openHomeChatTabProvider.notifier).state++;
      },
    );
  }
}

class _AdminSquareTile extends StatelessWidget {
  const _AdminSquareTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.adminTab,
    this.onTap,
    this.iconColor,
  }) : assert(adminTab != null || onTap != null);

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final String? adminTab;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () => openAdminOverlay(context, adminTab!),
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
        const LanguagePicker(isCompact: true),
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
          .select(
            'full_name,status,phone,nic,date_of_birth,district_id',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final status = row?['status'] as String? ?? 'active';
      final incomplete =
          ProfileCompleteness.fromProfile(row).missingKeys.isNotEmpty ||
              status == 'pending_registration' ||
              status == 'pending_approval';
      setState(() {
        _fullName = row?['full_name'] as String?;
        _status = incomplete ? 'pending_registration' : status;
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
    final l10n = AppLocalizations.of(context);
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
                l10n.settings,
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
              const SizedBox(height: 16),
              Text(
                l10n.language,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: SyuColors.mist,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              const LanguagePicker(),
              if (_status == 'pending_registration') ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/registration'),
                  child: Text(l10n.completeRegistration),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const SyuIcon(SyuIcons.edit, size: 20),
                label: Text(
                  _status == 'pending_registration'
                      ? l10n.editProfile
                      : l10n.updateDetails,
                ),
              ),
              buttonGap,
              OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const SyuIcon(SyuIcons.notification, size: 20),
                label: Text(l10n.notificationsAndAccount),
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
                label: Text(l10n.signOut),
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
