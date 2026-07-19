import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Super admin: district + DN admins. District admin: DN admins only.
class StaffAdminsPanel extends StatefulWidget {
  const StaffAdminsPanel({super.key});

  @override
  State<StaffAdminsPanel> createState() => _StaffAdminsPanelState();
}

class _StaffAdminsPanelState extends State<StaffAdminsPanel> {
  bool _loading = true;
  bool _isSuperAdmin = false;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _dsDivisions = [];
  int? _districtFilter;
  String _roleFilter = 'all'; // all | district_admin | division_admin

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final superAdmin =
          await SupabaseBootstrap.client.rpc('is_super_admin') == true;
      final districtAdmin =
          await SupabaseBootstrap.client.rpc('is_district_admin') == true;
      if (!superAdmin && !districtAdmin) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final districts = (await SupabaseBootstrap.client
              .from('districts')
              .select('id,name')
              .order('name') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      int? districtFilter;
      if (!superAdmin) {
        final ids = await SupabaseBootstrap.client
            .rpc('my_district_admin_district_ids');
        final list = (ids as List?)?.map((e) => e as int).toList() ?? [];
        districtFilter = list.isEmpty ? null : list.first;
      }

      if (!mounted) return;
      setState(() {
        _isSuperAdmin = superAdmin;
        _districts = districts;
        _districtFilter = districtFilter;
        _roleFilter = superAdmin ? 'all' : 'division_admin';
      });
      await _reload();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final role = _isSuperAdmin
          ? (_roleFilter == 'all' ? null : _roleFilter)
          : 'division_admin';
      final raw = await SupabaseBootstrap.client.rpc(
        'list_managed_staff_admins',
        params: {
          'p_role_code': role,
          'p_district_id': _districtFilter,
          'p_ds_division_id': null,
        },
      );
      if (!mounted) return;
      setState(() {
        _rows = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDs(int districtId) async {
    final ds = await SupabaseBootstrap.client
        .from('ds_divisions')
        .select('id,name')
        .eq('district_id', districtId)
        .order('name');
    if (!mounted) return;
    setState(() {
      _dsDivisions = (ds as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SyuColors.paper,
      builder: (ctx) => _StaffAdminFormSheet(
        isSuperAdmin: _isSuperAdmin,
        districts: _districts,
        lockedDistrictId: _isSuperAdmin ? null : _districtFilter,
        existing: existing,
        onNeedDs: _loadDs,
        initialDs: _dsDivisions,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? l10n.staffAdminCreated : l10n.staffAdminUpdated,
          ),
        ),
      );
      await _reload();
    }
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    final id = row['user_id'] as String?;
    if (id == null) return;
    try {
      await SupabaseBootstrap.client.rpc(
        'admin_set_member_status',
        params: {'p_member_id': id, 'p_status': status},
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'suspended'
                ? l10n.memberSuspended
                : l10n.memberStatusUpdated,
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  String _roleLabel(String? code, AppLocalizations l10n) => switch (code) {
        'district_admin' => l10n.userTypeDistrictAdmins,
        'division_admin' => l10n.userTypeDivisionAdmins,
        _ => code ?? '',
      };

  String _scopeLabel(Map<String, dynamic> row) {
    final role = row['role_code'] as String?;
    if (role == 'district_admin') {
      return row['district_name'] as String? ?? '';
    }
    final dn = row['ds_division_name'] as String? ?? '';
    final dist = row['district_name'] as String? ?? '';
    if (dn.isEmpty) return dist;
    if (dist.isEmpty) return dn;
    return '$dn · $dist';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: SyuColors.paper,
      appBar: AppBar(
        title: Text(l10n.staffAdmins),
        backgroundColor: SyuColors.paper,
        foregroundColor: SyuColors.ink,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.staffAdminsSubtitle,
                  style: textTheme.bodyMedium?.copyWith(color: SyuColors.mist),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_isSuperAdmin) ...[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _roleFilter,
                          decoration: InputDecoration(
                            labelText: l10n.userTypes,
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(l10n.all),
                            ),
                            DropdownMenuItem(
                              value: 'district_admin',
                              child: Text(l10n.userTypeDistrictAdmins),
                            ),
                            DropdownMenuItem(
                              value: 'division_admin',
                              child: Text(l10n.userTypeDivisionAdmins),
                            ),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _roleFilter = v);
                            await _reload();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        // ignore: deprecated_member_use
                        value: _districtFilter,
                        decoration: InputDecoration(
                          labelText: l10n.district,
                          isDense: true,
                        ),
                        items: [
                          if (_isSuperAdmin)
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.all),
                            ),
                          ..._districts.map(
                            (d) => DropdownMenuItem<int?>(
                              value: d['id'] as int,
                              child: Text(d['name'] as String? ?? ''),
                            ),
                          ),
                        ],
                        onChanged: _isSuperAdmin
                            ? (v) async {
                                setState(() => _districtFilter = v);
                                await _reload();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: AdminPanelChrome.compactFilled,
                    onPressed: () => _openForm(),
                    icon: const SyuIcon(
                      SyuIcons.userAdd,
                      size: 16,
                      color: SyuColors.paper,
                    ),
                    label: Text(l10n.addStaffAdmin),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: SyuColors.crimson),
                  )
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noStaffAdmins,
                          style: textTheme.bodyMedium?.copyWith(
                            color: SyuColors.mist,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 20),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final row = _rows[i];
                            final status = row['status'] as String? ?? '';
                            final suspended = status == 'suspended';
                            final name =
                                (row['full_name'] as String?)?.trim().isNotEmpty ==
                                        true
                                    ? row['full_name'] as String
                                    : 'Unnamed';
                            final by = [
                              if ((row['suspended_by_name'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true)
                                (row['suspended_by_name'] as String).trim(),
                              if ((row['suspended_by_role'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true)
                                (row['suspended_by_role'] as String).trim(),
                            ].join(' | ');
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(right: 0),
                              title: Text(
                                name,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      _roleLabel(
                                        row['role_code'] as String?,
                                        l10n,
                                      ),
                                      _scopeLabel(row),
                                      row['email'] as String? ?? '',
                                      row['phone'] as String? ?? '',
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: SyuColors.mist,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (suspended && by.isNotEmpty)
                                    Text(
                                      '${l10n.suspendedBy}: $by',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: SyuColors.warning,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await _openForm(existing: row);
                                    return;
                                  }
                                  if (v == 'suspend') {
                                    await _setStatus(row, 'suspended');
                                    return;
                                  }
                                  if (v == 'active') {
                                    await _setStatus(row, 'active');
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.edit),
                                  ),
                                  if (!suspended)
                                    PopupMenuItem(
                                      value: 'suspend',
                                      child: Text(l10n.statusSuspended),
                                    ),
                                  if (suspended)
                                    PopupMenuItem(
                                      value: 'active',
                                      child: Text(l10n.statusActive),
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
    );
  }
}

class _StaffAdminFormSheet extends StatefulWidget {
  const _StaffAdminFormSheet({
    required this.isSuperAdmin,
    required this.districts,
    required this.lockedDistrictId,
    required this.onNeedDs,
    required this.initialDs,
    this.existing,
  });

  final bool isSuperAdmin;
  final List<Map<String, dynamic>> districts;
  final int? lockedDistrictId;
  final Future<void> Function(int districtId) onNeedDs;
  final List<Map<String, dynamic>> initialDs;
  final Map<String, dynamic>? existing;

  @override
  State<_StaffAdminFormSheet> createState() => _StaffAdminFormSheetState();
}

class _StaffAdminFormSheetState extends State<_StaffAdminFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late String _roleCode;
  int? _districtId;
  int? _dsId;
  List<Map<String, dynamic>> _ds = [];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['full_name'] as String? ?? '');
    _email = TextEditingController(text: e?['email'] as String? ?? '');
    _phone = TextEditingController(text: e?['phone'] as String? ?? '');
    _roleCode = e?['role_code'] as String? ??
        (widget.isSuperAdmin ? 'district_admin' : 'division_admin');
    _districtId = e?['district_id'] as int? ?? widget.lockedDistrictId;
    _dsId = e?['ds_division_id'] as int?;
    _ds = List<Map<String, dynamic>>.from(widget.initialDs);
    final districtForDs = _districtId;
    if (districtForDs != null &&
        (_roleCode == 'division_admin' || !_isEdit) &&
        _ds.isEmpty) {
      Future<void>(() async {
        final ds = await SupabaseBootstrap.client
            .from('ds_divisions')
            .select('id,name')
            .eq('district_id', districtForDs)
            .order('name');
        if (!mounted) return;
        setState(() {
          _ds = (ds as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleCode == 'district_admin' && _districtId == null) {
      setState(() {});
      return;
    }
    if (_roleCode == 'division_admin' && _dsId == null) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await SupabaseBootstrap.client.rpc(
          'admin_update_staff_admin',
          params: {
            'p_user_id': widget.existing!['user_id'],
            'p_full_name': _name.text.trim(),
            'p_phone': _phone.text.trim(),
          },
        );
        final mustChange = widget.existing!['must_change_password'] == true;
        final nextEmail = _email.text.trim().toLowerCase();
        final prevEmail =
            ((widget.existing!['email'] as String?) ?? '').toLowerCase();
        if (mustChange && nextEmail != prevEmail && nextEmail.contains('@')) {
          final res = await SupabaseBootstrap.client.functions.invoke(
            'admin-update-member-email',
            body: {
              'member_id': widget.existing!['user_id'],
              'email': nextEmail,
              'full_name': _name.text.trim(),
            },
          );
          final data = res.data;
          if (res.status != 200 || data is! Map || data['ok'] != true) {
            final err = data is Map ? data['error'] : data;
            throw Exception(err ?? 'Could not update email');
          }
        }
      } else {
        final res = await SupabaseBootstrap.client.functions.invoke(
          'admin-create-staff',
          body: {
            'full_name': _name.text.trim(),
            'email': _email.text.trim().toLowerCase(),
            'phone': _phone.text.trim(),
            'role_code': _roleCode,
            'district_id':
                _roleCode == 'district_admin' ? _districtId : null,
            'ds_division_id':
                _roleCode == 'division_admin' ? _dsId : null,
          },
        );
        final data = res.data;
        if (res.status != 200 || data is! Map || data['ok'] != true) {
          final err = data is Map ? data['error'] : data;
          throw Exception(err ?? 'Could not create admin (${res.status})');
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? l10n.editStaffAdmin : l10n.addStaffAdmin,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              if (!_isEdit && widget.isSuperAdmin)
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _roleCode,
                  decoration: InputDecoration(labelText: l10n.userTypes),
                  items: [
                    DropdownMenuItem(
                      value: 'district_admin',
                      child: Text(l10n.userTypeDistrictAdmins),
                    ),
                    DropdownMenuItem(
                      value: 'division_admin',
                      child: Text(l10n.userTypeDivisionAdmins),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _roleCode = v;
                      if (v == 'district_admin') _dsId = null;
                    });
                  },
                ),
              if (!_isEdit && widget.isSuperAdmin) const SizedBox(height: 10),
              if (!_isEdit &&
                  (_roleCode == 'district_admin' ||
                      _roleCode == 'division_admin'))
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: _districtId,
                  decoration: InputDecoration(labelText: '${l10n.district} *'),
                  items: [
                    for (final d in widget.districts)
                      if (widget.lockedDistrictId == null ||
                          d['id'] == widget.lockedDistrictId)
                        DropdownMenuItem(
                          value: d['id'] as int,
                          child: Text(d['name'] as String? ?? ''),
                        ),
                  ],
                  onChanged: widget.lockedDistrictId != null
                      ? null
                      : (v) async {
                          setState(() {
                            _districtId = v;
                            _dsId = null;
                            _ds = [];
                          });
                          if (v != null && _roleCode == 'division_admin') {
                            final ds = await SupabaseBootstrap.client
                                .from('ds_divisions')
                                .select('id,name')
                                .eq('district_id', v)
                                .order('name');
                            if (!mounted) return;
                            setState(() {
                              _ds = (ds as List)
                                  .map((e) => Map<String, dynamic>.from(e as Map))
                                  .toList();
                            });
                          }
                        },
                  validator: (v) =>
                      v == null ? l10n.districtRequired : null,
                ),
              if (!_isEdit && _roleCode == 'division_admin') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: _dsId,
                  decoration: InputDecoration(
                    labelText: '${l10n.dsDivision} *',
                  ),
                  items: [
                    for (final d in _ds)
                      DropdownMenuItem(
                        value: d['id'] as int,
                        child: Text(d['name'] as String? ?? ''),
                      ),
                  ],
                  onChanged: (v) => setState(() => _dsId = v),
                  validator: (v) => v == null ? l10n.dsRequired : null,
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: '${l10n.fullName} *'),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? l10n.nameRequired : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                enabled: !_isEdit || widget.existing?['must_change_password'] == true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: '${l10n.email} *'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty || !t.contains('@')) return l10n.emailRequired;
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: '${l10n.phone} *'),
                validator: (v) =>
                    (v == null || v.trim().length < 9) ? l10n.phoneRequired : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: AdminPanelChrome.compactFilled.copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SyuColors.paper,
                        ),
                      )
                    : Text(_isEdit ? l10n.save : l10n.createStaffAdmin),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
