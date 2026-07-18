import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_audit_panel.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_clubs_panel.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_members_panel.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _checking = true;
  bool _allowed = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _check();
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
                    onPressed: () => context.go('/home'),
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
        title: const Text('SYU Admin'),
        actions: [
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Member app'),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.how_to_reg_outlined),
                label: Text('Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                label: Text('Members'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.groups_outlined),
                label: Text('Clubs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.campaign_outlined),
                label: Text('News'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_outlined),
                label: Text('Events'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('Audit'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _ApprovalQueue(),
                AdminMembersPanel(),
                AdminClubsPanel(),
                _AdminAnnouncements(),
                _AdminEvents(),
                _AdminReports(),
                AdminAuditPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalQueue extends StatefulWidget {
  const _ApprovalQueue();

  @override
  State<_ApprovalQueue> createState() => _ApprovalQueueState();
}

class _ApprovalQueueState extends State<_ApprovalQueue> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseBootstrap.client
          .from('profiles')
          .select('id,full_name,email,phone,nic,status,created_at')
          .eq('status', 'pending_approval')
          .order('created_at');
      setState(() => _rows = List<Map<String, dynamic>>.from(rows as List));
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await SupabaseBootstrap.client
          .from('profiles')
          .update({'status': status}).eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SyuColors.crimson),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No pending registrations'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = _rows[i];
          return Card(
            child: ListTile(
              title: Text(p['full_name'] as String? ?? 'Unnamed'),
              subtitle: Text(
                '${p['email'] ?? ''}\n${p['phone'] ?? ''} · NIC ${p['nic'] ?? '-'}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _setStatus(p['id'] as String, 'active'),
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _setStatus(p['id'] as String, 'suspended'),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminAnnouncements extends StatefulWidget {
  const _AdminAnnouncements();

  @override
  State<_AdminAnnouncements> createState() => _AdminAnnouncementsState();
}

class _AdminAnnouncementsState extends State<_AdminAnnouncements> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseBootstrap.client.from('announcements').insert({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'audience': 'all',
        'is_published': true,
        'published_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': SupabaseBootstrap.client.auth.currentUser?.id,
      });
      _title.clear();
      _body.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement published')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Publish announcement',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          decoration: const InputDecoration(labelText: 'Body'),
          minLines: 4,
          maxLines: 8,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _publish,
          child: const Text('Publish'),
        ),
      ],
    );
  }
}

class _AdminEvents extends StatefulWidget {
  const _AdminEvents();

  @override
  State<_AdminEvents> createState() => _AdminEventsState();
}

class _AdminEventsState extends State<_AdminEvents> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  DateTime _starts = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseBootstrap.client.from('events').insert({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'location_text': _location.text.trim(),
        'starts_at': _starts.toUtc().toIso8601String(),
        'is_published': true,
        'created_by': SupabaseBootstrap.client.auth.currentUser?.id,
      });
      _title.clear();
      _desc.clear();
      _location.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event published')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Create event', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          decoration: const InputDecoration(labelText: 'Description'),
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Starts: ${_starts.toIso8601String().split('T').first}'),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _starts,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _starts = d);
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: const Text('Publish event'),
        ),
      ],
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
      padding: const EdgeInsets.all(20),
      children: [
        Text('Membership', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ..._members.map(
          (r) => ListTile(
            title: Text('${r['status']}'),
            trailing: Text('${r['member_count']}'),
          ),
        ),
        const SizedBox(height: 24),
        Text('Events', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ..._events.map(
          (r) => ListTile(
            title: Text('${r['title']}'),
            subtitle: Text('RSVPs: ${r['rsvp_count']} · Going: ${r['going_count']}'),
          ),
        ),
      ],
    );
  }
}
