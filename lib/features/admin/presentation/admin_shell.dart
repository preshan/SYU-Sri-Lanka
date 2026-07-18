import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_audit_panel.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_broadcast_panels.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chat_panel.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_clubs_panel.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_members_panel.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({
    super.key,
    this.initialTab = 0,
    this.initialMemberId,
    this.initialMemberName,
    this.onLeave,
  });

  /// Approvals=0, Members=1, Clubs=2, News=3, Events=4, Chat=5, Broadcast=6, Reports=7, Audit=8
  final int initialTab;
  final String? initialMemberId;
  final String? initialMemberName;

  /// Called when the user leaves admin tools (back / Dashboard).
  /// Prefer this over a route pop so admin never stacks as a sibling page.
  final VoidCallback? onLeave;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  static const _titles = [
    'Approvals',
    'Members',
    'Clubs',
    'News',
    'Events',
    'Chat',
    'Broadcast',
    'Reports',
    'Audit',
  ];

  bool _checking = true;
  bool _allowed = false;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _titles.length - 1);
    _check();
  }

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab.clamp(0, _titles.length - 1);
    }
  }

  Future<void> _check() async {
    try {
      final ok = await SupabaseBootstrap.client.rpc('is_super_admin');
      setState(() => _allowed = ok == true);
    } catch (e) {
      AppErrorMapper.log(e);
      setState(() => _allowed = false);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _leave() {
    // Always go home — do not capture a pageBuilder context in onLeave.
    if (widget.onLeave != null) {
      widget.onLeave!();
      return;
    }
    context.go('/home');
  }

  Widget get _panel {
    return switch (_tab) {
      0 => const _ApprovalQueue(),
      1 => const AdminMembersPanel(),
      2 => const AdminClubsPanel(),
      3 => const AdminAnnouncementsPanel(),
      4 => const AdminEventsPanel(),
      5 => AdminChatPanel(
        initialMemberId: widget.initialMemberId,
        initialMemberName: widget.initialMemberName,
      ),
      6 => const AdminBroadcastPanel(),
      7 => const _AdminReports(),
      8 => const AdminAuditPanel(),
      _ => const AdminMembersPanel(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: SyuColors.crimson)),
      );
    }
    if (!_allowed) {
      return SyuGradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Admin access required',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in with a super_admin account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _leave,
                    child: const Text('Back to app'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        titleSpacing: 0,
        leading: IconButton(
          icon: const SyuIcon(SyuIcons.back),
          tooltip: 'Admin dashboard',
          onPressed: _leave,
        ),
        title: Text(
          _titles[_tab],
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: _leave,
            child: const Text('Dashboard'),
          ),
        ],
      ),
      body: _panel,
    );
  }
}

class _ApprovalQueue extends StatelessWidget {
  const _ApprovalQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SyuIcon(SyuIcons.verified,
                size: 48, color: SyuColors.crimsonSoft),
            const SizedBox(height: 16),
            Text(
              'Registrations are auto-approved',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'New members become active on submit. Use Members from the dashboard to manage accounts.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminReports extends StatefulWidget {
  const _AdminReports();

  @override
  State<_AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<_AdminReports> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await SupabaseBootstrap.client
          .from('admin_membership_summary')
          .select();
      final e = await SupabaseBootstrap.client
          .from('admin_events_summary')
          .select()
          .order('starts_at', ascending: false)
          .limit(20);
      setState(() {
        _members = List<Map<String, dynamic>>.from(m as List);
        _events = List<Map<String, dynamic>>.from(e as List);
      });
    } catch (err) {
      if (mounted) AppErrorMapper.showSnackBar(context, err);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SyuColors.crimson),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        Text(
          'Membership',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        ..._members.map(
          (r) => ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            title: Text('${r['status']}'),
            trailing: Text('${r['member_count']}'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Events',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        ..._events.map(
          (r) => ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            title: Text('${r['title']}'),
            subtitle: Text(
              'RSVPs: ${r['rsvp_count']} · Going: ${r['going_count']}',
            ),
          ),
        ),
      ],
    );
  }
}
