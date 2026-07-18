import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/export/csv_download.dart';
import 'package:syu_sri_lanka/core/export/syu_csv.dart';
import 'package:syu_sri_lanka/core/permissions/app_permissions.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class AdminMembersPanel extends StatefulWidget {
  const AdminMembersPanel({super.key, this.initialListMode});

  /// `all` | `saved`
  final String? initialListMode;

  @override
  State<AdminMembersPanel> createState() => _AdminMembersPanelState();
}

class _AdminMembersPanelState extends State<AdminMembersPanel> {
  static const _pageSize = 50;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _dsDivisions = [];
  List<Map<String, dynamic>> _gsDivisions = [];
  List<Map<String, dynamic>> _divisionAdmins = [];
  bool _loadingDivisionAdmins = false;
  /// When true, district filter is fixed to the district admin's scope.
  bool _districtFilterLocked = false;
  bool _dsFilterLocked = false;
  bool _isSuperAdmin = false;
  bool _isDistrictAdmin = false;
  bool _isDivisionAdmin = false;
  /// Multi-select user types. Default: members only.
  final Set<String> _userTypes = {'member'};

  /// null = ALL districts
  int? _districtFilter;
  /// null = ALL DS divisions
  int? _dsFilter;
  /// null = ALL GS (GN) divisions
  int? _gsFilter;
  String _status = 'all';
  /// Language filters: null = any; true = must speak
  bool? _filterSinhala;
  bool? _filterTamil;
  bool? _filterEnglish;
  /// 'all' | 'saved'
  late String _listMode;
  final Set<String> _savedIds = {};
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _filtersExpanded = false;

  bool _bootstrapping = true;
  bool _loading = false;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    final mode = widget.initialListMode;
    _listMode = mode == 'saved' ? 'saved' : 'all';
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _sanitizedSearch {
    final raw = _searchQuery.trim();
    if (raw.isEmpty) return '';
    // Strip PostgREST filter metacharacters from user input.
    return raw.replaceAll(RegExp(r'[%*,()]'), '');
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh clear button only
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      final next = value.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
      await _load(resetPage: true);
    });
  }

  bool get _isDivisionOnly =>
      _isDivisionAdmin && !_isSuperAdmin && !_isDistrictAdmin;

  bool get _canFilterDistrictAdmins =>
      _isSuperAdmin || _isDistrictAdmin;

  bool get _showDivisionAdminsStrip =>
      !_isDivisionOnly &&
      (_isSuperAdmin || _isDistrictAdmin) &&
      _districtFilter != null;

  Future<void> _bootstrap() async {
    setState(() => _bootstrapping = true);
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      final districts = await SupabaseBootstrap.client
          .from('districts')
          .select('id,name')
          .order('name');
      int? adminDistrict;
      int? lockedDs;
      var lockDistrict = false;
      var lockDs = false;
      var isSuper = false;
      var isDistrictAdmin = false;
      var isDivisionAdmin = false;
      if (uid != null) {
        final me = await SupabaseBootstrap.client
            .from('profiles')
            .select('district_id,ds_division_id')
            .eq('id', uid)
            .maybeSingle();
        isSuper =
            await SupabaseBootstrap.client.rpc('is_super_admin') == true;
        isDistrictAdmin =
            await SupabaseBootstrap.client.rpc('is_district_admin') == true;
        isDivisionAdmin =
            await SupabaseBootstrap.client.rpc('is_division_admin') == true;
        adminDistrict = me?['district_id'] as int?;

        if (isDistrictAdmin && !isSuper) {
          lockDistrict = true;
          final scoped = await SupabaseBootstrap.client
              .rpc('my_district_admin_district_ids');
          final ids = (scoped as List?)
                  ?.map((e) => e is int ? e : int.tryParse('$e'))
                  .whereType<int>()
                  .toList() ??
              const <int>[];
          if (ids.isNotEmpty) {
            adminDistrict = ids.first;
          }
        }

        // Division-only: lock district + DS to their scope.
        if (isDivisionAdmin && !isSuper && !isDistrictAdmin) {
          lockDistrict = true;
          lockDs = true;
          final scopedDs = await SupabaseBootstrap.client
              .rpc('my_division_admin_ds_ids');
          final dsIds = (scopedDs as List?)
                  ?.map((e) => e is int ? e : int.tryParse('$e'))
                  .whereType<int>()
                  .toList() ??
              const <int>[];
          if (dsIds.isNotEmpty) {
            lockedDs = dsIds.first;
            final dsRow = await SupabaseBootstrap.client
                .from('ds_divisions')
                .select('district_id')
                .eq('id', lockedDs)
                .maybeSingle();
            adminDistrict = dsRow?['district_id'] as int? ?? adminDistrict;
          }
        }
      }
      setState(() {
        _districts = List<Map<String, dynamic>>.from(districts as List);
        _districtFilter = adminDistrict;
        _districtFilterLocked = lockDistrict && adminDistrict != null;
        _dsFilterLocked = lockDs && lockedDs != null;
        _isSuperAdmin = isSuper;
        _isDistrictAdmin = isDistrictAdmin;
        _isDivisionAdmin = isDivisionAdmin;
        _userTypes
          ..clear()
          ..add('member');
        if (!_canFilterDistrictAdmins) {
          _userTypes.remove('district_admin');
        }
      });
      if (adminDistrict != null) {
        await _loadDs(adminDistrict);
        if (lockedDs != null) {
          setState(() => _dsFilter = lockedDs);
          await _loadGs(lockedDs);
        }
      }
      await _loadSavedIds();
      await _loadDivisionAdmins();
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
        if (!_dsFilterLocked) _dsFilter = null;
        _gsDivisions = [];
        _gsFilter = null;
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
      if (!_dsFilterLocked) {
        _dsFilter = null; // reset DS to ALL when district changes
        _gsDivisions = [];
        _gsFilter = null;
      }
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
        .select('id,name,ds_division_id')
        .eq('ds_division_id', dsId)
        .order('name');
    setState(() {
      _gsDivisions = List<Map<String, dynamic>>.from(rows as List);
      _gsFilter = null;
    });
  }

  Future<void> _loadSavedIds() async {
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    final rows = await SupabaseBootstrap.client
        .from('admin_saved_members')
        .select('member_id')
        .eq('admin_id', uid);
    setState(() {
      _savedIds
        ..clear()
        ..addAll(
          (rows as List).map((r) => (r as Map)['member_id'] as String),
        );
    });
  }

  Future<void> _loadDivisionAdmins() async {
    final districtId = _districtFilter;
    // Always load when a district is selected for district/super admins.
    final shouldShow = (_isSuperAdmin || _isDistrictAdmin) &&
        !_isDivisionOnly &&
        districtId != null;
    if (!shouldShow) {
      if (mounted) {
        setState(() {
          _divisionAdmins = [];
          _loadingDivisionAdmins = false;
        });
      }
      return;
    }
    setState(() => _loadingDivisionAdmins = true);
    try {
      final idParams = <String, dynamic>{
        'p_user_types': ['division_admin'],
        'p_district_id': districtId,
      };
      if (_dsFilter != null) {
        idParams['p_ds_division_id'] = _dsFilter;
      }
      final rawIds = await SupabaseBootstrap.client.rpc(
        'directory_user_ids',
        params: idParams,
      );
      final ids = (rawIds as List?)
              ?.map((e) => '$e')
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() => _divisionAdmins = []);
        return;
      }

      final rows = await SupabaseBootstrap.client
          .from('profiles')
          .select('id,full_name,phone,ds_division_id')
          .inFilter('id', ids)
          .order('full_name');

      final dsNameById = <int, String>{
        for (final d in _dsDivisions)
          if (d['id'] is int)
            d['id'] as int: (d['name'] as String?) ?? '',
      };
      final missingDs = (rows as List)
          .map((r) => (r as Map)['ds_division_id'])
          .whereType<int>()
          .where((id) => !dsNameById.containsKey(id))
          .toSet();
      if (missingDs.isNotEmpty) {
        final dsRows = await SupabaseBootstrap.client
            .from('ds_divisions')
            .select('id,name')
            .eq('district_id', districtId);
        for (final d in dsRows as List) {
          final map = d as Map;
          final id = map['id'];
          if (id is int) {
            dsNameById[id] = (map['name'] as String?) ?? '';
          }
        }
      }

      final mapped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final p = Map<String, dynamic>.from(row as Map);
        final dsId = p['ds_division_id'] as int?;
        mapped.add({
          'user_id': p['id'],
          'full_name': p['full_name'],
          'phone': p['phone'],
          'ds_division_id': dsId,
          'ds_division_name': dsId == null ? null : dsNameById[dsId],
        });
      }
      if (!mounted) return;
      setState(() => _divisionAdmins = mapped);
    } catch (e) {
      if (mounted) {
        setState(() => _divisionAdmins = []);
        AppErrorMapper.showSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _loadingDivisionAdmins = false);
    }
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() => _loading = true);
    try {
      if (_listMode == 'saved') {
        await _loadSavedList();
      } else {
        await _loadAllMembers();
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAllMembers() async {
    final from = _page * _pageSize;
    final to = from + _pageSize - 1;

    final types = _userTypes.isEmpty
        ? <String>['member']
        : _userTypes
            .where(
              (t) =>
                  t == 'member' ||
                  t == 'division_admin' ||
                  (t == 'district_admin' && _canFilterDistrictAdmins),
            )
            .toList();
    if (types.isEmpty) types.add('member');

    final idParams = <String, dynamic>{
      'p_user_types': types,
    };
    if (_districtFilter != null) {
      idParams['p_district_id'] = _districtFilter;
    }
    if (_dsFilter != null) {
      idParams['p_ds_division_id'] = _dsFilter;
    }

    final rawIds = await SupabaseBootstrap.client.rpc(
      'directory_user_ids',
      params: idParams,
    );
    final ids = (rawIds as List?)
            ?.map((e) => '$e')
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    if (ids.isEmpty) {
      setState(() {
        _rows = [];
        _total = 0;
      });
      return;
    }

    PostgrestFilterBuilder query = SupabaseBootstrap.client
        .from('profiles')
        .select(
          'id,full_name,email,nic,phone,status,created_at,date_of_birth,gender,'
          'district_id,ds_division_id,gn_division_id,requested_youth_club_name,'
          'youth_club_registration_no,'
          'speaks_sinhala,speaks_tamil,speaks_english,other_qualification,'
          'occupation,'
          'member_qualifications(qualification_id, qualifications(code,name_en,level_order))',
        )
        .inFilter('id', ids);

    if (_status != 'all') {
      query = query.eq('status', _status);
    }
    if (_gsFilter != null) {
      query = query.eq('gn_division_id', _gsFilter!);
    }
    if (_filterSinhala == true) {
      query = query.eq('speaks_sinhala', true);
    }
    if (_filterTamil == true) {
      query = query.eq('speaks_tamil', true);
    }
    if (_filterEnglish == true) {
      query = query.eq('speaks_english', true);
    }
    final q = _sanitizedSearch;
    if (q.isNotEmpty) {
      final pattern = '%$q%';
      query = query.or(
        'full_name.ilike.$pattern,email.ilike.$pattern,nic.ilike.$pattern,phone.ilike.$pattern',
      );
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    setState(() {
      _rows = List<Map<String, dynamic>>.from(response.data as List);
      _total = response.count;
    });
  }

  Future<void> _loadSavedList() async {
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    if (uid == null) return;
    final from = _page * _pageSize;
    final to = from + _pageSize - 1;

    var query = SupabaseBootstrap.client
        .from('admin_saved_members')
        .select(
          'member_id,note,created_at, profiles!inner(id,full_name,email,nic,phone,status,created_at,date_of_birth,gender,district_id,ds_division_id,gn_division_id,requested_youth_club_name,speaks_sinhala,speaks_tamil,speaks_english,member_qualifications(qualification_id, qualifications(code,name_en,level_order)))',
        )
        .eq('admin_id', uid);

    final q = _sanitizedSearch;
    if (q.isNotEmpty) {
      final pattern = '%$q%';
      query = query.or(
        'full_name.ilike.$pattern,email.ilike.$pattern,nic.ilike.$pattern',
        referencedTable: 'profiles',
      );
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    final mapped = <Map<String, dynamic>>[];
    for (final row in response.data as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final profile = map['profiles'];
      if (profile is Map) {
        final p = Map<String, dynamic>.from(profile);
        p['saved_note'] = map['note'];
        p['saved_at'] = map['created_at'];
        mapped.add(p);
      }
    }
    setState(() {
      _rows = mapped;
      _total = response.count;
    });
  }

  int get _totalPages =>
      _total == 0 ? 1 : ((_total + _pageSize - 1) / _pageSize).floor();

  Future<void> _toggleSave(Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final saved = _savedIds.contains(id);
    try {
      if (saved) {
        await SupabaseBootstrap.client.rpc(
          'admin_unsave_member',
          params: {'p_member_id': id},
        );
        setState(() => _savedIds.remove(id));
        if (_listMode == 'saved') await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved')),
          );
        }
      } else {
        await SupabaseBootstrap.client.rpc(
          'admin_save_member',
          params: {'p_member_id': id},
        );
        setState(() => _savedIds.add(id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved for quick access')),
          );
        }
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

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

  Future<void> _exportMembers() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing export…')),
      );
      final rows = await _fetchExportRows();
      if (!mounted) return;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No members to export')),
        );
        return;
      }
      final csv = SyuCsv.table(
        headers: const [
          'full_name',
          'email',
          'nic',
          'phone',
          'status',
          'gender',
          'date_of_birth',
          'occupation',
          'district_id',
          'ds_division_id',
          'gn_division_id',
          'qualifications',
          'other_qualification',
          'languages',
          'youth_club_name',
          'youth_club_registration_no',
        ],
        rows: rows
            .map(
              (u) => [
                u['full_name'],
                u['email'],
                u['nic'],
                u['phone'],
                u['status'],
                u['gender'],
                u['date_of_birth'],
                u['occupation'],
                u['district_id'],
                u['ds_division_id'],
                u['gn_division_id'],
                SyuCsv.qualificationsJoined(u),
                u['other_qualification'],
                SyuCsv.languagesJoined(u),
                u['requested_youth_club_name'],
                u['youth_club_registration_no'],
              ],
            )
            .toList(),
      );
      final filename = SyuCsv.membersFilename(
        districtName: _districtFilter == null
            ? null
            : _nameFrom(_districts, _districtFilter),
        dsName: _dsFilter == null ? null : _nameFrom(_dsDivisions, _dsFilter),
        gnName: _gsFilter == null ? null : _nameFrom(_gsDivisions, _gsFilter),
      );
      downloadTextFile(filename: filename, content: csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported $filename (${rows.length}) — open in Google Sheets or Excel',
          ),
        ),
      );
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  String? _nameFrom(List<Map<String, dynamic>> rows, int? id) {
    if (id == null) return null;
    for (final r in rows) {
      if (r['id'] == id) return r['name'] as String?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchExportRows() async {
    if (_listMode == 'saved') {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return [];
      final out = <Map<String, dynamic>>[];
      var from = 0;
      const page = 1000;
      final q = _sanitizedSearch;
      while (true) {
        var query = SupabaseBootstrap.client
            .from('admin_saved_members')
            .select(
              'profiles!inner(id,full_name,email,nic,phone,status,gender,date_of_birth,district_id,ds_division_id,gn_division_id,speaks_sinhala,speaks_tamil,speaks_english,member_qualifications(qualification_id, qualifications(code,name_en,level_order)))',
            )
            .eq('admin_id', uid);
        if (q.isNotEmpty) {
          final pattern = '%$q%';
          query = query.or(
            'full_name.ilike.$pattern,email.ilike.$pattern,nic.ilike.$pattern',
            referencedTable: 'profiles',
          );
        }
        final chunk = await query.range(from, from + page - 1);
        final list = chunk as List;
        for (final row in list) {
          final map = Map<String, dynamic>.from(row as Map);
          final profile = map['profiles'];
          if (profile is Map) {
            out.add(Map<String, dynamic>.from(profile));
          }
        }
        if (list.length < page) break;
        from += page;
        if (from >= 10000) break;
      }
      return out;
    }

    final out = <Map<String, dynamic>>[];
    var from = 0;
    const page = 1000;
    final q = _sanitizedSearch;

    final types = _userTypes.isEmpty
        ? <String>['member']
        : _userTypes
            .where(
              (t) =>
                  t == 'member' ||
                  t == 'division_admin' ||
                  (t == 'district_admin' && _canFilterDistrictAdmins),
            )
            .toList();
    if (types.isEmpty) types.add('member');
    final idParams = <String, dynamic>{'p_user_types': types};
    if (_districtFilter != null) idParams['p_district_id'] = _districtFilter;
    if (_dsFilter != null) idParams['p_ds_division_id'] = _dsFilter;
    final rawIds = await SupabaseBootstrap.client.rpc(
      'directory_user_ids',
      params: idParams,
    );
    final ids = (rawIds as List?)?.map((e) => '$e').toList() ?? const <String>[];
    if (ids.isEmpty) return [];

    while (true) {
      PostgrestFilterBuilder query =
          SupabaseBootstrap.client.from('profiles').select(
                'id,full_name,email,nic,phone,status,gender,date_of_birth,'
                'occupation,other_qualification,'
                'district_id,ds_division_id,gn_division_id,'
                'requested_youth_club_name,youth_club_registration_no,'
                'speaks_sinhala,speaks_tamil,speaks_english,'
                'member_qualifications(qualification_id, qualifications(code,name_en,level_order))',
              ).inFilter('id', ids);
      if (_status != 'all') query = query.eq('status', _status);
      if (_gsFilter != null) query = query.eq('gn_division_id', _gsFilter!);
      if (_filterSinhala == true) query = query.eq('speaks_sinhala', true);
      if (_filterTamil == true) query = query.eq('speaks_tamil', true);
      if (_filterEnglish == true) query = query.eq('speaks_english', true);
      if (q.isNotEmpty) {
        final pattern = '%$q%';
        query = query.or(
          'full_name.ilike.$pattern,email.ilike.$pattern,nic.ilike.$pattern,phone.ilike.$pattern',
        );
      }
      final chunk = await query
          .order('created_at', ascending: false)
          .range(from, from + page - 1);
      final list = List<Map<String, dynamic>>.from(chunk as List);
      out.addAll(list);
      if (list.length < page) break;
      from += page;
      if (from >= 10000) break;
    }
    return out;
  }

  Future<void> _messageMember(Map<String, dynamic> p) async {
    final id = p['id'] as String;
    final name = (p['full_name'] as String?)?.trim().isNotEmpty == true
        ? p['full_name'] as String
        : (p['email'] as String? ?? 'Member');
    if (!mounted) return;
    context.push(
      '/admin?tab=chat&member=${Uri.encodeComponent(id)}'
      '&name=${Uri.encodeComponent(name)}',
    );
  }

  String _districtName(int? id) {
    if (id == null) return '-';
    for (final d in _districts) {
      if (d['id'] == id) return d['name'] as String? ?? '$id';
    }
    return '$id';
  }

  String _languageLabel(Map<String, dynamic> p) {
    final langs = <String>[
      if (p['speaks_sinhala'] == true) 'Sinhala',
      if (p['speaks_tamil'] == true) 'Tamil',
      if (p['speaks_english'] == true) 'English',
    ];
    if (langs.isEmpty) return '';
    return langs.join(', ');
  }

  String _genderLabel(Map<String, dynamic> p) {
    final g = (p['gender'] as String?)?.trim().toLowerCase();
    if (g == null || g.isEmpty) return '';
    return switch (g) {
      'male' => 'Male',
      'female' => 'Female',
      'other' => 'Other',
      _ => g[0].toUpperCase() + g.substring(1),
    };
  }

  String? _ageLabel(Map<String, dynamic> p) {
    final raw = p['date_of_birth'];
    if (raw == null) return null;
    final dob = DateTime.tryParse(raw.toString());
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age -= 1;
    }
    if (age < 0 || age > 120) return null;
    return '$age yrs';
  }

  String _highestQualificationLabel(Map<String, dynamic> p) {
    final raw = p['member_qualifications'];
    if (raw is! List || raw.isEmpty) return '';
    Map<String, dynamic>? best;
    var bestOrder = -1;
    for (final row in raw) {
      if (row is! Map) continue;
      final q = row['qualifications'];
      if (q is! Map) continue;
      final code = (q['code'] as String?)?.toLowerCase();
      final order = (q['level_order'] as num?)?.toInt() ?? 0;
      // "other" sorts last unless it's the only entry.
      final effective = code == 'other' ? -1 : order;
      if (best == null || effective > bestOrder) {
        bestOrder = effective;
        best = Map<String, dynamic>.from(q);
      }
    }
    if (best == null) return '';
    final code = (best['code'] as String?)?.toLowerCase();
    if (code == 'ol') return 'O/L';
    if (code == 'al') return 'A/L';
    return best['name_en'] as String? ?? code ?? '';
  }

  String _memberSubtitle(Map<String, dynamic> p, AppLocalizations l10n) {
    final nic = (p['nic'] as String?)?.trim();
    final phone = (p['phone'] as String?)?.trim();
    final line1 = <String>[
      if ((p['email'] as String?)?.isNotEmpty == true) p['email'] as String,
      if (phone != null && phone.isNotEmpty) phone,
    ].join(' · ');
    final line2 = <String>[
      if (nic != null && nic.isNotEmpty) nic,
      if (_genderLabel(p).isNotEmpty) _genderLabel(p),
      if (_ageLabel(p) != null) _ageLabel(p)!,
      if ((p['occupation'] as String?)?.trim().isNotEmpty == true)
        (p['occupation'] as String).trim(),
    ].join(' · ');
    final status = p['status'] as String? ?? '';
    final line3 = <String>[
      _statusLabel(status, l10n),
      _districtName(p['district_id'] as int?),
      if (_highestQualificationLabel(p).isNotEmpty)
        _highestQualificationLabel(p),
      if ((p['other_qualification'] as String?)?.trim().isNotEmpty == true)
        (p['other_qualification'] as String).trim(),
      if (_languageLabel(p).isNotEmpty) _languageLabel(p),
      if ((p['requested_youth_club_name'] as String?)?.isNotEmpty == true)
        p['requested_youth_club_name'] as String,
      if ((p['youth_club_registration_no'] as String?)?.trim().isNotEmpty ==
          true)
        (p['youth_club_registration_no'] as String).trim(),
    ].where((s) => s.isNotEmpty && s != '-').join(' · ');
    return [line1, line2, line3].where((l) => l.isNotEmpty).join('\n');
  }

  Future<void> _callPhone(String? raw) async {
    final phone = raw?.trim() ?? '';
    if (phone.isEmpty) return;
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final ok = await AppPermissions.openLink('tel:$digits');
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start call')),
      );
    }
  }

  int get _languageFilterCount => [
        _filterSinhala,
        _filterTamil,
        _filterEnglish,
      ].where((v) => v == true).length;

  int get _activeFilterCount {
    var n = 0;
    if (_districtFilter != null) n++;
    if (_dsFilter != null) n++;
    if (_gsFilter != null) n++;
    if (_status != 'all') n++;
    n += _languageFilterCount;
    if (!_userTypes.contains('member') ||
        _userTypes.length != 1 ||
        _userTypes.contains('district_admin') ||
        _userTypes.contains('division_admin')) {
      // Count as active unless default members-only.
      if (!(_userTypes.length == 1 && _userTypes.contains('member'))) {
        n++;
      }
    }
    return n;
  }

  String _userTypesLabel(AppLocalizations l10n) {
    if (_userTypes.isEmpty ||
        (_userTypes.length == 1 && _userTypes.contains('member'))) {
      return l10n.userTypeMembers;
    }
    final labels = <String>[
      if (_userTypes.contains('member')) l10n.userTypeMembers,
      if (_userTypes.contains('district_admin') && _canFilterDistrictAdmins)
        l10n.userTypeDistrictAdmins,
      if (_userTypes.contains('division_admin')) l10n.userTypeDivisionAdmins,
    ];
    if (labels.isEmpty) return l10n.userTypeMembers;
    return labels.join(', ');
  }

  Widget _userTypesFilterMenu(AppLocalizations l10n) {
    Future<void> toggle(String type) async {
      setState(() {
        if (_userTypes.contains(type)) {
          if (_userTypes.length > 1) {
            _userTypes.remove(type);
          }
        } else {
          if (type == 'district_admin' && !_canFilterDistrictAdmins) return;
          _userTypes.add(type);
        }
        if (_userTypes.isEmpty) _userTypes.add('member');
      });
      await _load(resetPage: true);
      if (_showDivisionAdminsStrip) {
        await _loadDivisionAdmins();
      } else if (mounted) {
        setState(() => _divisionAdmins = []);
      }
    }

    return PopupMenuButton<String>(
      tooltip: l10n.userTypes,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 36),
      onSelected: (v) => toggle(v),
      itemBuilder: (_) => [
        CheckedPopupMenuItem<String>(
          value: 'member',
          checked: _userTypes.contains('member'),
          child: Text(l10n.userTypeMembers),
        ),
        if (_canFilterDistrictAdmins)
          CheckedPopupMenuItem<String>(
            value: 'district_admin',
            checked: _userTypes.contains('district_admin'),
            child: Text(l10n.userTypeDistrictAdmins),
          ),
        CheckedPopupMenuItem<String>(
          value: 'division_admin',
          checked: _userTypes.contains('division_admin'),
          child: Text(l10n.userTypeDivisionAdmins),
        ),
      ],
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
                '${l10n.userTypes}: ${_userTypesLabel(l10n)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: SyuColors.mist),
          ],
        ),
      ),
    );
  }

  String _languageFilterLabel(AppLocalizations l10n) {
    final selected = <String>[
      if (_filterSinhala == true) 'Sinhala',
      if (_filterTamil == true) 'Tamil',
      if (_filterEnglish == true) 'English',
    ];
    if (selected.isEmpty) return 'Any';
    if (selected.length == 3) return l10n.all;
    return selected.join(', ');
  }

  String _districtLabel(int? id, AppLocalizations l10n) {
    if (id == null) return l10n.all;
    for (final d in _districts) {
      if (d['id'] == id) return d['name'] as String? ?? '$id';
    }
    return '$id';
  }

  String _dsLabel(int? id, AppLocalizations l10n) {
    if (id == null) return l10n.all;
    for (final d in _dsDivisions) {
      if (d['id'] == id) return d['name'] as String? ?? '$id';
    }
    return '$id';
  }

  String _gsLabel(int? id, AppLocalizations l10n) {
    if (id == null) return l10n.all;
    for (final d in _gsDivisions) {
      if (d['id'] == id) return d['name'] as String? ?? '$id';
    }
    return '$id';
  }

  String _statusLabel(String status, AppLocalizations l10n) => switch (status) {
        'pending_registration' => l10n.statusPending,
        'active' => l10n.statusActive,
        'suspended' => l10n.statusSuspended,
        _ => l10n.all,
      };

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
      offset: const Offset(0, 36),
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
              const Icon(Icons.arrow_drop_down_rounded, size: 18, color: SyuColors.mist),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languagesFilterMenu() {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context);
        final active = _languageFilterCount > 0;
        return Material(
          color: active
              ? SyuColors.crimson.withValues(alpha: 0.08)
              : SyuColors.inkSoft,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: SizedBox(
              height: 32,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lang · ${_languageFilterLabel(l10n)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          color: active ? SyuColors.crimsonDeep : SyuColors.ink,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      controller.isOpen
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: SyuColors.mist,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      menuChildren: [
        CheckboxMenuButton(
          value: _filterSinhala == true,
          onChanged: (on) async {
            setState(() => _filterSinhala = on == true ? true : null);
            await _load(resetPage: true);
          },
          child: const Text('Sinhala'),
        ),
        CheckboxMenuButton(
          value: _filterTamil == true,
          onChanged: (on) async {
            setState(() => _filterTamil = on == true ? true : null);
            await _load(resetPage: true);
          },
          child: const Text('Tamil'),
        ),
        CheckboxMenuButton(
          value: _filterEnglish == true,
          onChanged: (on) async {
            setState(() => _filterEnglish = on == true ? true : null);
            await _load(resetPage: true);
          },
          child: const Text('English'),
        ),
        if (_languageFilterCount > 0)
          MenuItemButton(
            onPressed: () async {
              setState(() {
                _filterSinhala = null;
                _filterTamil = null;
                _filterEnglish = null;
              });
              await _load(resetPage: true);
            },
            child: const Text('Clear languages'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Center(
        child: CircularProgressIndicator(color: SyuColors.crimson),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      style: ButtonStyle(
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: WidgetStatePropertyAll(
                          textTheme.labelMedium?.copyWith(fontSize: 12),
                        ),
                      ),
                      segments: [
                        ButtonSegment(value: 'all', label: Text(l10n.all)),
                        ButtonSegment(
                          value: 'saved',
                          label: Text(l10n.savedWithCount(_savedIds.length)),
                        ),
                      ],
                      selected: {_listMode},
                      onSelectionChanged: (s) async {
                        setState(() => _listMode = s.first);
                        await _load(resetPage: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_total',
                    style: textTheme.labelMedium?.copyWith(
                      color: SyuColors.mist,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Export CSV',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: _exportMembers,
                    icon: const Icon(Icons.download_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                style: textTheme.bodySmall?.copyWith(fontSize: 13),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) async {
                  _searchDebounce?.cancel();
                  setState(() => _searchQuery = v.trim());
                  await _load(resetPage: true);
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.searchMembersHint,
                  hintStyle: textTheme.bodySmall?.copyWith(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clear,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () async {
                            _search.clear();
                            _searchDebounce?.cancel();
                            setState(() => _searchQuery = '');
                            await _load(resetPage: true);
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                        ),
                  filled: true,
                  fillColor: SyuColors.inkSoft,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: SyuColors.crimson,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              if (_listMode == 'all') ...[
                const SizedBox(height: 6),
                _userTypesFilterMenu(l10n),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: const VisualDensity(
                        horizontal: -3,
                        vertical: -3,
                      ),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _activeFilterCount > 0
                          ? SyuColors.crimson
                          : SyuColors.mist,
                    ),
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    icon: Icon(
                      _filtersExpanded
                          ? Icons.expand_less_rounded
                          : Icons.tune_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _filtersExpanded
                          ? l10n.hideFilters
                          : (_activeFilterCount == 0
                              ? l10n.filters
                              : l10n.filtersWithCount(_activeFilterCount)),
                      style: textTheme.labelMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                if (_filtersExpanded) ...[
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = (constraints.maxWidth - 6) / 2;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          SizedBox(
                            width: w,
                            child: _compactSelect(
                              label: 'District',
                              valueText: _districtLabel(_districtFilter, l10n),
                              enabled: !_districtFilterLocked,
                              onSelected: (v) async {
                                if (_districtFilterLocked) return;
                                final id = v == -1 ? null : v as int?;
                                setState(() => _districtFilter = id);
                                await _loadDs(id);
                                await _loadDivisionAdmins();
                                await _load(resetPage: true);
                              },
                              items: [
                                if (!_districtFilterLocked)
                                  PopupMenuItem<Object?>(
                                    value: -1,
                                    child: Text(l10n.all),
                                  ),
                                ..._districts.map(
                                  (d) => PopupMenuItem<Object?>(
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
                              valueText: _dsLabel(_dsFilter, l10n),
                              enabled:
                                  _districtFilter != null && !_dsFilterLocked,
                              onSelected: (v) async {
                                if (_dsFilterLocked) return;
                                final id = v == -1 ? null : v as int?;
                                setState(() => _dsFilter = id);
                                await _loadGs(id);
                                await _loadDivisionAdmins();
                                await _load(resetPage: true);
                              },
                              items: [
                                PopupMenuItem<Object?>(
                                  value: -1,
                                  child: Text(l10n.all),
                                ),
                                ..._dsDivisions.map(
                                  (d) => PopupMenuItem<Object?>(
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
                              valueText: _gsLabel(_gsFilter, l10n),
                              enabled: _dsFilter != null,
                              onSelected: (v) async {
                                final id = v == -1 ? null : v as int?;
                                setState(() => _gsFilter = id);
                                await _load(resetPage: true);
                              },
                              items: [
                                PopupMenuItem<Object?>(
                                  value: -1,
                                  child: Text(l10n.all),
                                ),
                                ..._gsDivisions.map(
                                  (d) => PopupMenuItem<Object?>(
                                    value: d['id'] as int,
                                    child: Text(
                                      d['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: w,
                            child: _compactSelect(
                              label: 'Status',
                              valueText: _statusLabel(_status, l10n),
                              onSelected: (v) async {
                                if (v is! String) return;
                                setState(() => _status = v);
                                await _load(resetPage: true);
                              },
                              items: [
                                PopupMenuItem(
                                  value: 'all',
                                  child: Text(l10n.all),
                                ),
                                PopupMenuItem(
                                  value: 'pending_registration',
                                  child: Text(l10n.statusPending),
                                ),
                                PopupMenuItem(
                                  value: 'active',
                                  child: Text(l10n.statusActive),
                                ),
                                PopupMenuItem(
                                  value: 'suspended',
                                  child: Text(l10n.statusSuspended),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: w, child: _languagesFilterMenu()),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showDivisionAdminsStrip)
                _DivisionAdminsHeader(
                  loading: _loadingDivisionAdmins,
                  admins: _divisionAdmins,
                  onCall: _callPhone,
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SyuColors.crimson,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadDivisionAdmins();
                          await _load();
                        },
                        child: _rows.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 40),
                                  Center(
                                    child: Text(
                                      _listMode == 'saved'
                                          ? 'No saved members yet'
                                          : 'No members for this filter',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: SyuColors.mist,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 2, 6),
                                itemCount: _rows.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: SyuColors.border,
                                ),
                                itemBuilder: (context, i) {
                                  final p = _rows[i];
                                  final id = p['id'] as String;
                                  final saved = _savedIds.contains(id);
                                  final phone =
                                      (p['phone'] as String?)?.trim() ?? '';
                                  return ListTile(
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                      horizontal: 0,
                                      vertical: -2,
                                    ),
                                    contentPadding: const EdgeInsets.only(
                                      left: 2,
                                      right: 0,
                                    ),
                                    minVerticalPadding: 4,
                                    title: Text(
                                      p['full_name'] as String? ?? 'Unnamed',
                                      style:
                                          textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        height: 1.15,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _memberSubtitle(p, l10n),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: SyuColors.mist,
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (phone.isNotEmpty)
                                          IconButton(
                                            tooltip: 'Call $phone',
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            icon: const SyuIcon(
                                              SyuIcons.phone,
                                              size: 18,
                                              color: SyuColors.crimson,
                                            ),
                                            onPressed: () => _callPhone(phone),
                                          ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.more_vert,
                                            size: 18,
                                            color: saved
                                                ? SyuColors.crimson
                                                : SyuColors.mist,
                                          ),
                                          onSelected: (s) async {
                                            if (s == 'message') {
                                              await _messageMember(p);
                                              return;
                                            }
                                            if (s == 'save' ||
                                                s == 'unsave') {
                                              await _toggleSave(p);
                                              return;
                                            }
                                            if (s == 'call') {
                                              await _callPhone(phone);
                                              return;
                                            }
                                            await _setStatus(id, s);
                                          },
                                          itemBuilder: (_) => [
                                            if (phone.isNotEmpty)
                                              PopupMenuItem(
                                                value: 'call',
                                                child: Text('Call $phone'),
                                              ),
                                            PopupMenuItem(
                                              value: 'message',
                                              child:
                                                  Text(l10n.messageAction),
                                            ),
                                            PopupMenuItem(
                                              value:
                                                  saved ? 'unsave' : 'save',
                                              child: Text(
                                                saved
                                                    ? 'Remove from saved'
                                                    : 'Save for quick access',
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'active',
                                              child:
                                                  Text(l10n.statusActive),
                                            ),
                                            PopupMenuItem(
                                              value: 'suspended',
                                              child: Text(
                                                  l10n.statusSuspended),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
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

}

class _DivisionAdminsHeader extends StatefulWidget {
  const _DivisionAdminsHeader({
    required this.loading,
    required this.admins,
    required this.onCall,
  });

  final bool loading;
  final List<Map<String, dynamic>> admins;
  final Future<void> Function(String? phone) onCall;

  @override
  State<_DivisionAdminsHeader> createState() => _DivisionAdminsHeaderState();
}

class _DivisionAdminsHeaderState extends State<_DivisionAdminsHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final admins = widget.admins;
    final visible = (!widget.loading && admins.length > 1 && !_expanded)
        ? admins.take(1).toList()
        : admins;
    final hiddenCount =
        admins.length > 1 && !_expanded ? admins.length - 1 : 0;

    return Material(
      color: SyuColors.inkSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.divisionAdmins,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SyuColors.crimson,
                    ),
                  ),
                ),
              )
            else if (admins.isEmpty)
              Text(
                l10n.noDivisionAdmins,
                style: textTheme.bodySmall?.copyWith(
                  color: SyuColors.mist,
                  fontSize: 12,
                ),
              )
            else ...[
              ...visible.map(_adminTile),
              if (admins.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: SyuColors.crimson,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -3,
                        vertical: -3,
                      ),
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _expanded
                          ? 'Show less'
                          : 'Show $hiddenCount more',
                      style: textTheme.labelMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                ),
            ],
            const Divider(height: 12, color: SyuColors.border),
          ],
        ),
      ),
    );
  }

  Widget _adminTile(Map<String, dynamic> a) {
    final textTheme = Theme.of(context).textTheme;
    final name = (a['full_name'] as String?)?.trim().isNotEmpty == true
        ? a['full_name'] as String
        : 'Unnamed';
    final phone = (a['phone'] as String?)?.trim() ?? '';
    final ds = (a['ds_division_name'] as String?)?.trim() ?? '';
    final titleLine = ds.isEmpty ? name : '$name | $ds';
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 2,
      onTap: phone.isEmpty ? null : () => widget.onCall(phone),
      title: Text(
        titleLine,
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: phone.isNotEmpty
          ? GestureDetector(
              onTap: () => widget.onCall(phone),
              child: Text(
                phone,
                style: textTheme.bodySmall?.copyWith(
                  color: SyuColors.crimson,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: SyuColors.crimson,
                ),
              ),
            )
          : Text(
              'No phone',
              style: textTheme.bodySmall?.copyWith(
                color: SyuColors.mist,
                fontSize: 11,
              ),
            ),
      trailing: phone.isEmpty
          ? null
          : IconButton(
              tooltip: 'Call $phone',
              visualDensity: VisualDensity.compact,
              icon: const SyuIcon(
                SyuIcons.phone,
                size: 18,
                color: SyuColors.crimson,
              ),
              onPressed: () => widget.onCall(phone),
            ),
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
    final l10n = AppLocalizations.of(context);
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
                l10n.rangeOf(from, to, total),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: onPrev,
                icon: const SyuIcon(SyuIcons.chevronLeft),
                tooltip: 'Previous page',
              ),
              Text(
                l10n.pageLabel(page + 1, totalPages),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                onPressed: onNext,
                icon: const SyuIcon(SyuIcons.chevronRight),
                tooltip: 'Next page',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
