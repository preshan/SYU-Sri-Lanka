import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/export/csv_download.dart';
import 'package:syu_sri_lanka/core/export/syu_csv.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_audience_picker.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';

class AdminAnnouncementsPanel extends StatefulWidget {
  const AdminAnnouncementsPanel({super.key});

  @override
  State<AdminAnnouncementsPanel> createState() =>
      _AdminAnnouncementsPanelState();
}

class _AdminAnnouncementsPanelState extends State<AdminAnnouncementsPanel> {
  static const _pageSize = AdminPanelChrome.pageSize;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int _page = 0;
  int _total = 0;

  int get _totalPages => AdminPanelChrome.totalPages(_total, _pageSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() => _loading = true);
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      final response = await SupabaseBootstrap.client
          .from('announcements')
          .select(
            'id,title,body,audience,district_id,ds_division_id,gn_division_id,'
            'is_published,published_at,created_at,updated_at',
          )
          .order('created_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);
      setState(() {
        _items = List<Map<String, dynamic>>.from(response.data as List);
        _total = response.count;
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: const Text('Members will no longer see this news item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseBootstrap.client.from('announcements').delete().eq('id', id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AnnouncementEditorSheet(existing: existing),
    );
    if (saved == true) await _load(resetPage: existing == null);
  }

  void _view(Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['title'] as String? ?? 'Announcement'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _audienceLabel(item),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SyuColors.mist,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                (item['is_published'] == true) ? 'Published' : 'Draft',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: SyuColors.crimson,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 8),
              Text(item['body'] as String? ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openEditor(existing: item);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminPanelChrome.toolbar(
          context: context,
          hint: '$_total news',
          actions: [
            FilledButton.icon(
              style: AdminPanelChrome.compactFilled,
              onPressed: () => _openEditor(),
              icon: const SyuIcon(SyuIcons.add, size: 16, color: SyuColors.paper),
              label: const Text('Create'),
            ),
          ],
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : RefreshIndicator(
                  color: SyuColors.crimson,
                  onRefresh: () => _load(),
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 32),
                            Center(
                              child: Text(
                                'No announcements yet.',
                                style: AdminPanelChrome.hintStyle(context),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: AdminPanelChrome.listPadding,
                          itemCount: _items.length,
                          separatorBuilder: (_, _) =>
                              AdminPanelChrome.denseDivider(),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final published = item['is_published'] == true;
                            final date = (item['published_at'] ??
                                    item['created_at'] ??
                                    '')
                                .toString()
                                .split('T')
                                .first;
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -3,
                              ),
                              contentPadding: EdgeInsets.zero,
                              minVerticalPadding: 2,
                              onTap: () => _view(item),
                              title: Text(
                                item['title'] as String? ?? '',
                                style: AdminPanelChrome.rowTitleStyle(context),
                              ),
                              subtitle: Text(
                                '$date · ${_audienceLabel(item)}'
                                '${published ? '' : ' · Draft'}',
                                style: AdminPanelChrome.rowMetaStyle(context),
                              ),
                              trailing: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (s) async {
                                  switch (s) {
                                    case 'view':
                                      _view(item);
                                    case 'edit':
                                      await _openEditor(existing: item);
                                    case 'delete':
                                      await _delete(item['id'] as String);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Text('View'),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
        AdminPaginationBar(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          pageSize: _pageSize,
          onPrev: _page <= 0
              ? null
              : () async {
                  setState(() => _page -= 1);
                  await _load();
                },
          onNext: _page + 1 >= _totalPages
              ? null
              : () async {
                  setState(() => _page += 1);
                  await _load();
                },
        ),
      ],
    );
  }
}

class _AnnouncementEditorSheet extends StatefulWidget {
  const _AnnouncementEditorSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_AnnouncementEditorSheet> createState() =>
      _AnnouncementEditorSheetState();
}

class _AnnouncementEditorSheetState extends State<_AnnouncementEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late AudienceSelection _audience;
  bool _saving = false;
  bool _notify = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title'] as String? ?? '');
    _body = TextEditingController(text: e?['body'] as String? ?? '');
    _audience = AudienceSelection(
      audience: e?['audience'] as String? ?? 'all',
      districtId: e?['district_id'] as int?,
      dsDivisionId: e?['ds_division_id'] as int?,
      gnDivisionId: e?['gn_division_id'] as int?,
    );
    _notify = !_isEdit;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final err = _audience.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await SupabaseBootstrap.client.from('announcements').update({
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'audience': _audience.audience,
          'district_id':
              _audience.audience == 'all' ? null : _audience.districtId,
          'ds_division_id':
              (_audience.audience == 'ds' || _audience.audience == 'gn')
                  ? _audience.dsDivisionId
                  : null,
          'gn_division_id':
              _audience.audience == 'gn' ? _audience.gnDivisionId : null,
        }).eq('id', widget.existing!['id'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement updated')),
          );
        }
      } else if (_notify) {
        final res = await SupabaseBootstrap.client.rpc(
          'admin_publish_announcement',
          params: {
            'p_title': _title.text.trim(),
            'p_body': _body.text.trim(),
            'p_audience': _audience.audience,
            'p_district_id':
                _audience.audience == 'all' ? null : _audience.districtId,
            'p_ds_division_id':
                (_audience.audience == 'ds' || _audience.audience == 'gn')
                    ? _audience.dsDivisionId
                    : null,
            'p_gn_division_id':
                _audience.audience == 'gn' ? _audience.gnDivisionId : null,
          },
        );
        final notified = (res is Map ? res['notified'] : null) ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Published. Notified $notified members.')),
          );
        }
      } else {
        await SupabaseBootstrap.client.from('announcements').insert({
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'audience': _audience.audience,
          'district_id':
              _audience.audience == 'all' ? null : _audience.districtId,
          'ds_division_id':
              (_audience.audience == 'ds' || _audience.audience == 'gn')
                  ? _audience.dsDivisionId
                  : null,
          'gn_division_id':
              _audience.audience == 'gn' ? _audience.gnDivisionId : null,
          'is_published': true,
          'published_at': DateTime.now().toUtc().toIso8601String(),
          'created_by': SupabaseBootstrap.client.auth.currentUser?.id,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement published')),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit announcement' : 'Create announcement',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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
            AdminAudiencePicker(
              key: ValueKey(
                '${_audience.audience}-${_audience.districtId}-'
                '${_audience.dsDivisionId}-${_audience.gnDivisionId}',
              ),
              initial: _audience,
              onChanged: (a) => _audience = a,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify matching members'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: SyuColors.paper,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Publish'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminEventsPanel extends StatefulWidget {
  const AdminEventsPanel({super.key});

  @override
  State<AdminEventsPanel> createState() => _AdminEventsPanelState();
}

class _AdminEventsPanelState extends State<AdminEventsPanel> {
  static const _pageSize = AdminPanelChrome.pageSize;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _dsDivisions = [];
  List<Map<String, dynamic>> _gsDivisions = [];
  bool _loading = true;
  bool _filtersOpen = false;
  int _page = 0;
  int _total = 0;

  String? _audienceFilter; // null = all scopes
  int? _districtFilter;
  int? _dsFilter;
  int? _gsFilter;
  String _statusFilter = 'all'; // all | published | draft

  Map<String, dynamic>? _openEvent;
  List<Map<String, dynamic>> _audienceUsers = [];
  bool _usersLoading = false;

  int get _totalPages => AdminPanelChrome.totalPages(_total, _pageSize);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final districts = await SupabaseBootstrap.client
          .from('districts')
          .select('id,name')
          .order('name');
      setState(() {
        _districts = List<Map<String, dynamic>>.from(districts as List);
      });
    } catch (_) {}
    await _load();
  }

  Future<void> _loadDs(int? districtId) async {
    if (districtId == null) {
      setState(() {
        _dsDivisions = [];
        _dsFilter = null;
        _gsDivisions = [];
        _gsFilter = null;
      });
      return;
    }
    final rows = await SupabaseBootstrap.client
        .from('ds_divisions')
        .select('id,name')
        .eq('district_id', districtId)
        .order('name');
    setState(() {
      _dsDivisions = List<Map<String, dynamic>>.from(rows as List);
      _dsFilter = null;
      _gsDivisions = [];
      _gsFilter = null;
    });
  }

  Future<void> _loadGs(int? dsId) async {
    if (dsId == null) {
      setState(() {
        _gsDivisions = [];
        _gsFilter = null;
      });
      return;
    }
    final rows = await SupabaseBootstrap.client
        .from('gn_divisions')
        .select('id,name')
        .eq('ds_division_id', dsId)
        .order('name');
    setState(() {
      _gsDivisions = List<Map<String, dynamic>>.from(rows as List);
      _gsFilter = null;
    });
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() => _loading = true);
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      var query = SupabaseBootstrap.client.from('events').select(
            'id,title,description,starts_at,location_text,audience,'
            'district_id,ds_division_id,gn_division_id,is_published,created_at',
          );
      if (_audienceFilter != null) {
        query = query.eq('audience', _audienceFilter!);
      }
      if (_districtFilter != null) {
        query = query.eq('district_id', _districtFilter!);
      }
      if (_dsFilter != null) {
        query = query.eq('ds_division_id', _dsFilter!);
      }
      if (_gsFilter != null) {
        query = query.eq('gn_division_id', _gsFilter!);
      }
      if (_statusFilter == 'published') {
        query = query.eq('is_published', true);
      } else if (_statusFilter == 'draft') {
        query = query.eq('is_published', false);
      }
      final response = await query
          .order('starts_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);
      setState(() {
        _items = List<Map<String, dynamic>>.from(response.data as List);
        _total = response.count;
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('RSVPs for this event will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseBootstrap.client.from('events').delete().eq('id', id);
      if (_openEvent?['id'] == id) {
        setState(() {
          _openEvent = null;
          _audienceUsers = [];
        });
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _EventEditorSheet(existing: existing),
    );
    if (saved == true) await _load(resetPage: existing == null);
  }

  Future<void> _openEventUsers(Map<String, dynamic> event) async {
    setState(() {
      _openEvent = event;
      _usersLoading = true;
      _audienceUsers = [];
    });
    try {
      final users = await _fetchAudienceUsers(event);
      if (!mounted) return;
      setState(() => _audienceUsers = users);
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAudienceUsers(
    Map<String, dynamic> event,
  ) async {
    final eventId = event['id'] as String;
    final audience = event['audience'] as String? ?? 'all';
    final districtId = event['district_id'] as int?;
    final dsId = event['ds_division_id'] as int?;
    final gnId = event['gn_division_id'] as int?;

    final out = <Map<String, dynamic>>[];
    var from = 0;
    const page = 1000;
    while (true) {
      var query = SupabaseBootstrap.client.from('profiles').select(
            'id,full_name,email,nic,phone,status,district_id,ds_division_id,gn_division_id,'
            'speaks_sinhala,speaks_tamil,speaks_english,'
            'member_qualifications(qualification_id, qualifications(code,name_en,level_order))',
          );
      query = query.eq('status', 'active');
      switch (audience) {
        case 'district':
          if (districtId != null) query = query.eq('district_id', districtId);
        case 'ds':
          if (dsId != null) query = query.eq('ds_division_id', dsId);
        case 'gn':
          if (gnId != null) query = query.eq('gn_division_id', gnId);
      }
      final chunk = await query
          .order('full_name')
          .range(from, from + page - 1);
      final list = List<Map<String, dynamic>>.from(chunk as List);
      out.addAll(list);
      if (list.length < page) break;
      from += page;
      if (from >= 5000) break;
    }

    final rsvps = await SupabaseBootstrap.client
        .from('event_rsvps')
        .select('profile_id,status')
        .eq('event_id', eventId);
    final rsvpMap = <String, String>{};
    for (final r in rsvps as List) {
      final m = Map<String, dynamic>.from(r as Map);
      rsvpMap[m['profile_id'] as String] = m['status'] as String? ?? '';
    }
    for (final u in out) {
      u['rsvp_status'] = rsvpMap[u['id'] as String];
    }
    return out;
  }

  void _exportEventUsers() {
    final event = _openEvent;
    if (event == null) return;
    final title = event['title'] as String? ?? 'event';
    final csv = SyuCsv.table(
      headers: const [
        'full_name',
        'email',
        'nic',
        'phone',
        'status',
        'rsvp',
        'district_id',
        'ds_division_id',
        'gn_division_id',
        'qualifications',
        'languages',
      ],
      rows: _audienceUsers
          .map(
            (u) => [
              u['full_name'],
              u['email'],
              u['nic'],
              u['phone'],
              u['status'],
              u['rsvp_status'] ?? '',
              u['district_id'],
              u['ds_division_id'],
              u['gn_division_id'],
              SyuCsv.qualificationsJoined(u),
              SyuCsv.languagesJoined(u),
            ],
          )
          .toList(),
    );
    try {
      downloadTextFile(
        filename: SyuCsv.eventFilename(title),
        content: csv,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${SyuCsv.eventFilename(title)} — open in Google Sheets or Excel',
          ),
        ),
      );
    } catch (e) {
      AppErrorMapper.showSnackBar(context, e);
    }
  }

  String _nameOf(List<Map<String, dynamic>> rows, int? id) {
    if (id == null) return 'All';
    for (final r in rows) {
      if (r['id'] == id) return r['name'] as String? ?? '$id';
    }
    return '$id';
  }

  Widget _compactSelect({
    required String label,
    required String valueText,
    required List<PopupMenuEntry<Object?>> items,
    required ValueChanged<Object?> onSelected,
    bool enabled = true,
  }) {
    return PopupMenuButton<Object?>(
      enabled: enabled,
      tooltip: label,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 34),
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 8, right: 4),
          decoration: BoxDecoration(
            color: SyuColors.inkSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$label · $valueText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.1),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: SyuColors.mist,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_openEvent != null) {
      return _buildEventUsers(context);
    }
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: SyuColors.crimson),
      );
    }
    return Column(
      children: [
        AdminPanelChrome.toolbar(
          context: context,
          hint: '$_total events',
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              icon: Icon(
                _filtersOpen ? Icons.expand_less : Icons.tune_rounded,
                size: 16,
              ),
              label: Text(
                _filtersOpen ? 'Hide' : 'Filters',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            FilledButton.icon(
              style: AdminPanelChrome.compactFilled,
              onPressed: () => _openEditor(),
              icon: const SyuIcon(SyuIcons.add, size: 16, color: SyuColors.paper),
              label: const Text('Create'),
            ),
          ],
        ),
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 6) / 2;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SizedBox(
                      width: w,
                      child: _compactSelect(
                        label: 'Scope',
                        valueText: switch (_audienceFilter) {
                          'district' => 'District',
                          'ds' => 'DS',
                          'gn' => 'GN',
                          'all' => 'All members',
                          _ => 'Any',
                        },
                        onSelected: (v) async {
                          setState(() {
                            _audienceFilter =
                                v == '__any__' ? null : v as String?;
                          });
                          await _load(resetPage: true);
                        },
                        items: const [
                          PopupMenuItem(value: '__any__', child: Text('Any')),
                          PopupMenuItem(value: 'all', child: Text('All members')),
                          PopupMenuItem(
                            value: 'district',
                            child: Text('District'),
                          ),
                          PopupMenuItem(value: 'ds', child: Text('DS')),
                          PopupMenuItem(value: 'gn', child: Text('GN')),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _compactSelect(
                        label: 'District',
                        valueText: _nameOf(_districts, _districtFilter),
                        onSelected: (v) async {
                          final id = v == -1 ? null : v as int?;
                          setState(() => _districtFilter = id);
                          await _loadDs(id);
                          await _load(resetPage: true);
                        },
                        items: [
                          const PopupMenuItem(value: -1, child: Text('All')),
                          ..._districts.map(
                            (d) => PopupMenuItem(
                              value: d['id'] as int,
                              child: Text(d['name'] as String),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _compactSelect(
                        label: 'DS',
                        valueText: _nameOf(_dsDivisions, _dsFilter),
                        enabled: _districtFilter != null,
                        onSelected: (v) async {
                          final id = v == -1 ? null : v as int?;
                          setState(() => _dsFilter = id);
                          await _loadGs(id);
                          await _load(resetPage: true);
                        },
                        items: [
                          const PopupMenuItem(value: -1, child: Text('All')),
                          ..._dsDivisions.map(
                            (d) => PopupMenuItem(
                              value: d['id'] as int,
                              child: Text(d['name'] as String),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _compactSelect(
                        label: 'GS',
                        valueText: _nameOf(_gsDivisions, _gsFilter),
                        enabled: _dsFilter != null,
                        onSelected: (v) async {
                          final id = v == -1 ? null : v as int?;
                          setState(() => _gsFilter = id);
                          await _load(resetPage: true);
                        },
                        items: [
                          const PopupMenuItem(value: -1, child: Text('All')),
                          ..._gsDivisions.map(
                            (d) => PopupMenuItem(
                              value: d['id'] as int,
                              child: Text(d['name'] as String),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _compactSelect(
                        label: 'Status',
                        valueText: switch (_statusFilter) {
                          'published' => 'Published',
                          'draft' => 'Draft',
                          _ => 'All',
                        },
                        onSelected: (v) async {
                          setState(() => _statusFilter = v as String? ?? 'all');
                          await _load(resetPage: true);
                        },
                        items: const [
                          PopupMenuItem(value: 'all', child: Text('All')),
                          PopupMenuItem(
                            value: 'published',
                            child: Text('Published'),
                          ),
                          PopupMenuItem(value: 'draft', child: Text('Draft')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : RefreshIndicator(
                  color: SyuColors.crimson,
                  onRefresh: () => _load(),
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 32),
                            Center(
                              child: Text(
                                'No events yet.',
                                style: AdminPanelChrome.hintStyle(context),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: AdminPanelChrome.listPadding,
                          itemCount: _items.length,
                          separatorBuilder: (_, _) =>
                              AdminPanelChrome.denseDivider(),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final starts = (item['starts_at'] ?? '')
                                .toString()
                                .split('T')
                                .first;
                            final published = item['is_published'] == true;
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -3,
                              ),
                              contentPadding: EdgeInsets.zero,
                              minVerticalPadding: 2,
                              onTap: () => _openEventUsers(item),
                              title: Text(
                                item['title'] as String? ?? '',
                                style: AdminPanelChrome.rowTitleStyle(context),
                              ),
                              subtitle: Text(
                                '$starts · ${_audienceLabel(item)}'
                                '${published ? '' : ' · Draft'}',
                                style: AdminPanelChrome.rowMetaStyle(context),
                              ),
                              trailing: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (s) async {
                                  switch (s) {
                                    case 'users':
                                      await _openEventUsers(item);
                                    case 'edit':
                                      await _openEditor(existing: item);
                                    case 'delete':
                                      await _delete(item['id'] as String);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'users',
                                    child: Text('Audience / export'),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
        if (_openEvent == null)
          AdminPaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            pageSize: _pageSize,
            onPrev: _page <= 0
                ? null
                : () async {
                    setState(() => _page -= 1);
                    await _load();
                  },
            onNext: _page + 1 >= _totalPages
                ? null
                : () async {
                    setState(() => _page += 1);
                    await _load();
                  },
          ),
      ],
    );
  }

  Widget _buildEventUsers(BuildContext context) {
    final event = _openEvent!;
    final title = event['title'] as String? ?? 'Event';
    final starts = (event['starts_at'] ?? '').toString().split('T').first;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  _openEvent = null;
                  _audienceUsers = [];
                }),
                icon: const SyuIcon(SyuIcons.back, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminPanelChrome.rowTitleStyle(context),
                    ),
                    Text(
                      '$starts · ${_audienceLabel(event)} · ${_audienceUsers.length} members',
                      style: AdminPanelChrome.rowMetaStyle(context),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: AdminPanelChrome.compactFilled,
                onPressed:
                    _usersLoading || _audienceUsers.isEmpty ? null : _exportEventUsers,
                child: const Text('Export CSV'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _usersLoading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : _audienceUsers.isEmpty
                  ? Center(
                      child: Text(
                        'No matching members for this scope',
                        style: AdminPanelChrome.hintStyle(context),
                      ),
                    )
                  : ListView.separated(
                      padding: AdminPanelChrome.listPadding,
                      itemCount: _audienceUsers.length,
                      separatorBuilder: (_, _) =>
                          AdminPanelChrome.denseDivider(),
                      itemBuilder: (context, i) {
                        final u = _audienceUsers[i];
                        final rsvp = u['rsvp_status'] as String?;
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -2,
                          ),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            u['full_name'] as String? ?? 'Unnamed',
                            style: AdminPanelChrome.rowTitleStyle(context),
                          ),
                          subtitle: Text(
                            [
                              u['email'] ?? '',
                              if ((u['nic'] as String?)?.isNotEmpty == true)
                                u['nic'],
                              if (rsvp != null && rsvp.isNotEmpty)
                                'RSVP: $rsvp',
                            ].where((s) => '$s'.isNotEmpty).join(' · '),
                            style: AdminPanelChrome.rowMetaStyle(context),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _location;
  late DateTime _starts;
  late AudienceSelection _audience;
  bool _saving = false;
  bool _notify = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title'] as String? ?? '');
    _desc = TextEditingController(text: e?['description'] as String? ?? '');
    _location =
        TextEditingController(text: e?['location_text'] as String? ?? '');
    final raw = e?['starts_at'] as String?;
    _starts = raw != null
        ? DateTime.tryParse(raw)?.toLocal() ??
            DateTime.now().add(const Duration(days: 7))
        : DateTime.now().add(const Duration(days: 7));
    _audience = AudienceSelection(
      audience: e?['audience'] as String? ?? 'all',
      districtId: e?['district_id'] as int?,
      dsDivisionId: e?['ds_division_id'] as int?,
      gnDivisionId: e?['gn_division_id'] as int?,
    );
    _notify = !_isEdit;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final err = _audience.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await SupabaseBootstrap.client.from('events').update({
          'title': _title.text.trim(),
          'description': _desc.text.trim(),
          'location_text': _location.text.trim(),
          'starts_at': _starts.toUtc().toIso8601String(),
          'audience': _audience.audience,
          'district_id':
              _audience.audience == 'all' ? null : _audience.districtId,
          'ds_division_id':
              (_audience.audience == 'ds' || _audience.audience == 'gn')
                  ? _audience.dsDivisionId
                  : null,
          'gn_division_id':
              _audience.audience == 'gn' ? _audience.gnDivisionId : null,
        }).eq('id', widget.existing!['id'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated')),
          );
        }
      } else if (_notify) {
        final res = await SupabaseBootstrap.client.rpc(
          'admin_publish_event',
          params: {
            'p_title': _title.text.trim(),
            'p_description': _desc.text.trim(),
            'p_starts_at': _starts.toUtc().toIso8601String(),
            'p_location_text': _location.text.trim(),
            'p_audience': _audience.audience,
            'p_district_id':
                _audience.audience == 'all' ? null : _audience.districtId,
            'p_ds_division_id':
                (_audience.audience == 'ds' || _audience.audience == 'gn')
                    ? _audience.dsDivisionId
                    : null,
            'p_gn_division_id':
                _audience.audience == 'gn' ? _audience.gnDivisionId : null,
          },
        );
        final notified = (res is Map ? res['notified'] : null) ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Event published. Notified $notified members.'),
            ),
          );
        }
      } else {
        await SupabaseBootstrap.client.from('events').insert({
          'title': _title.text.trim(),
          'description': _desc.text.trim(),
          'location_text': _location.text.trim(),
          'starts_at': _starts.toUtc().toIso8601String(),
          'audience': _audience.audience,
          'district_id':
              _audience.audience == 'all' ? null : _audience.districtId,
          'ds_division_id':
              (_audience.audience == 'ds' || _audience.audience == 'gn')
                  ? _audience.dsDivisionId
                  : null,
          'gn_division_id':
              _audience.audience == 'gn' ? _audience.gnDivisionId : null,
          'is_published': true,
          'created_by': SupabaseBootstrap.client.auth.currentUser?.id,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event published')),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit event' : 'Create event',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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
              title: Text(
                'Starts: ${_starts.toIso8601String().split('T').first}',
              ),
              trailing: const SyuIcon(SyuIcons.calendar),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _starts,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _starts = d);
              },
            ),
            const SizedBox(height: 12),
            AdminAudiencePicker(
              key: ValueKey(
                '${_audience.audience}-${_audience.districtId}-'
                '${_audience.dsDivisionId}-${_audience.gnDivisionId}',
              ),
              initial: _audience,
              onChanged: (a) => _audience = a,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify matching members'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: SyuColors.paper,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Publish'),
            ),
          ],
        ),
      ),
    );
  }
}

String _audienceLabel(Map<String, dynamic> item) {
  final a = item['audience'] as String? ?? 'all';
  switch (a) {
    case 'district':
      return 'District';
    case 'ds':
      return 'DS division';
    case 'gn':
      return 'GN division';
    default:
      return 'All members';
  }
}

class AdminBroadcastPanel extends StatefulWidget {
  const AdminBroadcastPanel({super.key});

  @override
  State<AdminBroadcastPanel> createState() => _AdminBroadcastPanelState();
}

class _AdminBroadcastPanelState extends State<AdminBroadcastPanel> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  AudienceSelection _audience = const AudienceSelection();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final err = _audience.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await SupabaseBootstrap.client.rpc(
        'admin_broadcast_message',
        params: {
          'p_title': _title.text.trim(),
          'p_body': _body.text.trim(),
          'p_audience': _audience.audience,
          'p_district_id':
              _audience.audience == 'all' ? null : _audience.districtId,
          'p_ds_division_id':
              (_audience.audience == 'ds' || _audience.audience == 'gn')
                  ? _audience.dsDivisionId
                  : null,
          'p_gn_division_id':
              _audience.audience == 'gn' ? _audience.gnDivisionId : null,
        },
      );
      final notified = (res is Map ? res['notified'] : null) ?? 0;
      _title.clear();
      _body.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message sent to $notified members.')),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Text(
          'Sends to Notifications for the selected audience (not individual members).',
          style: AdminPanelChrome.hintStyle(context),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Title',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Message',
          ),
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: 10),
        AdminAudiencePicker(onChanged: (a) => _audience = a),
        const SizedBox(height: 14),
        FilledButton(
          style: AdminPanelChrome.compactFilled.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
          ),
          onPressed: _saving ? null : _send,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: SyuColors.paper,
                  ),
                )
              : const Text('Send notification'),
        ),
      ],
    );
  }
}
