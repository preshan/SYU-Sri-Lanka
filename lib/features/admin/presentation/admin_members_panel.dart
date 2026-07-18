import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

class AdminMembersPanel extends StatefulWidget {
  const AdminMembersPanel({super.key});

  @override
  State<AdminMembersPanel> createState() => _AdminMembersPanelState();
}

class _AdminMembersPanelState extends State<AdminMembersPanel> {
  static const _pageSize = 50;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _dsDivisions = [];

  /// null = ALL districts
  int? _districtFilter;
  /// null = ALL DS divisions
  int? _dsFilter;
  String _status = 'all';

  int? _adminDistrictId;
  bool _bootstrapping = true;
  bool _loading = false;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _bootstrapping = true);
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      final districts = await SupabaseBootstrap.client
          .from('districts')
          .select('id,name')
          .order('name');
      int? adminDistrict;
      if (uid != null) {
        final me = await SupabaseBootstrap.client
            .from('profiles')
            .select('district_id')
            .eq('id', uid)
            .maybeSingle();
        adminDistrict = me?['district_id'] as int?;
      }
      setState(() {
        _districts = List<Map<String, dynamic>>.from(districts as List);
        _adminDistrictId = adminDistrict;
        // Default to admin's district when set; otherwise ALL
        _districtFilter = adminDistrict;
      });
      if (adminDistrict != null) {
        await _loadDs(adminDistrict);
      }
      await _load(resetPage: true);
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  Future<void> _loadDs(int? districtId) async {
    if (districtId == null) {
      setState(() {
        _dsDivisions = [];
        _dsFilter = null;
      });
      return;
    }
    final rows = await SupabaseBootstrap.client
        .from('ds_divisions')
        .select('id,name,district_id')
        .eq('district_id', districtId)
        .order('name');
    setState(() {
      _dsDivisions = List<Map<String, dynamic>>.from(rows as List);
      _dsFilter = null; // reset DS to ALL when district changes
    });
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() => _loading = true);
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      PostgrestFilterBuilder query = SupabaseBootstrap.client
          .from('profiles')
          .select(
            'id,full_name,email,phone,status,created_at,district_id,ds_division_id,requested_youth_club_name',
          );

      if (_status != 'all') {
        query = query.eq('status', _status);
      }
      if (_districtFilter != null) {
        query = query.eq('district_id', _districtFilter!);
      }
      if (_dsFilter != null) {
        query = query.eq('ds_division_id', _dsFilter!);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      setState(() {
        _rows = List<Map<String, dynamic>>.from(response.data as List);
        _total = response.count;
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalPages =>
      _total == 0 ? 1 : ((_total + _pageSize - 1) / _pageSize).floor();

  Future<void> _setStatus(String id, String status) async {
    try {
      await SupabaseBootstrap.client
          .from('profiles')
          .update({'status': status}).eq('id', id);
      await SupabaseBootstrap.client.from('activity_logs').insert({
        'actor_id': SupabaseBootstrap.client.auth.currentUser?.id,
        'action': 'member_status_changed',
        'entity_type': 'profile',
        'entity_id': id,
        'metadata': {'status': status},
      });
      await _load();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  String _districtName(int? id) {
    if (id == null) return '-';
    for (final d in _districts) {
      if (d['id'] == id) return d['name'] as String? ?? '$id';
    }
    return '$id';
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Center(
        child: CircularProgressIndicator(color: SyuColors.crimson),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Members', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '$_total total',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              if (_adminDistrictId == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Tip: set your profile district so the default filter matches your area.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SyuColors.mist,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _filterChip(
                    label: 'District',
                    child: DropdownButton<int?>(
                      value: _districtFilter,
                      hint: const Text('District'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('ALL'),
                        ),
                        ..._districts.map(
                          (d) => DropdownMenuItem<int?>(
                            value: d['id'] as int,
                            child: Text(d['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (v) async {
                        setState(() => _districtFilter = v);
                        await _loadDs(v);
                        await _load(resetPage: true);
                      },
                    ),
                  ),
                  _filterChip(
                    label: 'DS',
                    child: DropdownButton<int?>(
                      value: _dsFilter,
                      hint: const Text('DS'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('ALL'),
                        ),
                        ..._dsDivisions.map(
                          (d) => DropdownMenuItem<int?>(
                            value: d['id'] as int,
                            child: Text(d['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: _districtFilter == null
                          ? null
                          : (v) async {
                              setState(() => _dsFilter = v);
                              await _load(resetPage: true);
                            },
                    ),
                  ),
                  _filterChip(
                    label: 'Status',
                    child: DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ALL')),
                        DropdownMenuItem(
                          value: 'pending_registration',
                          child: Text('Incomplete'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspended'),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _status = v);
                        await _load(resetPage: true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: _rows.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('No members for this filter')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = _rows[i];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  p['full_name'] as String? ?? 'Unnamed',
                                ),
                                subtitle: Text(
                                  [
                                    '${p['email'] ?? ''}',
                                    '${p['status']} · ${_districtName(p['district_id'] as int?)}',
                                    if ((p['requested_youth_club_name']
                                                as String?)
                                            ?.isNotEmpty ==
                                        true)
                                      'Club: ${p['requested_youth_club_name']}',
                                  ].join('\n'),
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (s) =>
                                      _setStatus(p['id'] as String, s),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'active',
                                      child: Text('Set active'),
                                    ),
                                    PopupMenuItem(
                                      value: 'suspended',
                                      child: Text('Suspend'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
        _PaginationBar(
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

  Widget _filterChip({required String label, required Widget child}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium),
        child,
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = total == 0 ? 0 : ((page + 1) * pageSize).clamp(0, total);
    return Material(
      color: SyuColors.inkElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                '$from–$to of $total',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
              ),
              Text(
                'Page ${page + 1} / $totalPages',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
