import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';
import 'package:syu_sri_lanka/features/admin/presentation/organizer_contact_tile.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Super / district admin UI — manage organizers for any district.
class DivisionalOrganizersPanel extends StatefulWidget {
  const DivisionalOrganizersPanel({super.key});

  @override
  State<DivisionalOrganizersPanel> createState() =>
      _DivisionalOrganizersPanelState();
}

class _DivisionalOrganizersPanelState extends State<DivisionalOrganizersPanel> {
  bool _loading = true;
  int? _districtId;
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _dsDivisions = [];
  List<Map<String, dynamic>> _organizers = [];

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
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      final allDistricts = await SupabaseBootstrap.client
          .from('districts')
          .select('id,name')
          .order('name');
      final districts = (allDistricts as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _districtId = districts.isEmpty ? null : districts.first['id'] as int;
      });
      await _reload();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final districtId = _districtId;
    if (districtId == null) {
      setState(() {
        _dsDivisions = [];
        _organizers = [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final ds = await SupabaseBootstrap.client
          .from('ds_divisions')
          .select('id,name')
          .eq('district_id', districtId)
          .order('name');
      final raw = await SupabaseBootstrap.client.rpc(
        'list_divisional_organizers',
        params: {'p_district_id': districtId},
      );
      if (!mounted) return;
      setState(() {
        _dsDivisions = (ds as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _organizers = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final districtId = _districtId;
    if (districtId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _OrganizerEditDialog(
        districtId: districtId,
        dsDivisions: _dsDivisions,
        existing: existing,
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: SyuColors.paper,
      appBar: AppBar(
        title: Text(l10n.divisionalOrganizers),
        backgroundColor: SyuColors.paper,
        foregroundColor: SyuColors.ink,
        elevation: 0,
      ),
      body: _loading && _organizers.isEmpty && _dsDivisions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: SyuColors.crimson),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Text(
                    l10n.divisionalOrganizersManageSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SyuColors.mist,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: AdminPanelChrome.compactFilled,
                      onPressed: _districtId == null || _dsDivisions.isEmpty
                          ? null
                          : () => _openEditor(),
                      icon: const SyuIcon(
                        SyuIcons.add,
                        size: 16,
                        color: SyuColors.paper,
                      ),
                      label: Text(l10n.addOrganizer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _districtId,
                    decoration: InputDecoration(labelText: l10n.district),
                    items: [
                      for (final d in _districts)
                        DropdownMenuItem(
                          value: d['id'] as int,
                          child: Text(d['name'] as String? ?? ''),
                        ),
                    ],
                    onChanged: (v) async {
                      setState(() => _districtId = v);
                      await _reload();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: SyuColors.crimson,
                        ),
                      ),
                    )
                  else if (_organizers.isEmpty)
                    Text(
                      l10n.noDivisionalOrganizers,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SyuColors.mist,
                          ),
                    )
                  else
                    for (final o in _organizers) ...[
                      Material(
                        color: SyuColors.inkElevated,
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: SyuColors.border),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                          child: OrganizerContactTile(
                            fullName:
                                (o['full_name'] as String?)?.trim() ?? 'Unnamed',
                            dsName:
                                (o['ds_division_name'] as String?)?.trim() ?? '',
                            mobile: (o['mobile'] as String?)?.trim() ?? '',
                            landline: (o['landline'] as String?)?.trim(),
                            email: (o['email'] as String?)?.trim(),
                            onEdit: () => _openEditor(existing: o),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class _OrganizerEditDialog extends StatefulWidget {
  const _OrganizerEditDialog({
    required this.districtId,
    required this.dsDivisions,
    required this.existing,
  });

  final int districtId;
  final List<Map<String, dynamic>> dsDivisions;
  final Map<String, dynamic>? existing;

  @override
  State<_OrganizerEditDialog> createState() => _OrganizerEditDialogState();
}

class _OrganizerEditDialogState extends State<_OrganizerEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _landline;
  late final TextEditingController _email;
  int? _dsDivisionId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: (e?['full_name'] as String?) ?? '');
    _mobile = TextEditingController(text: (e?['mobile'] as String?) ?? '');
    _landline = TextEditingController(text: (e?['landline'] as String?) ?? '');
    _email = TextEditingController(text: (e?['email'] as String?) ?? '');
    _dsDivisionId = e?['ds_division_id'] as int? ??
        (widget.dsDivisions.isEmpty
            ? null
            : widget.dsDivisions.first['id'] as int);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _landline.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_dsDivisionId == null) {
      setState(() => _error = l10n.dsDivision);
      return;
    }
    if (_name.text.trim().length < 2 || _mobile.text.trim().length < 7) {
      setState(() => _error = l10n.organizerFieldsRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseBootstrap.client.rpc(
        'upsert_divisional_organizer',
        params: {
          'p_district_id': widget.districtId,
          'p_ds_division_id': _dsDivisionId,
          'p_full_name': _name.text.trim(),
          'p_mobile': _mobile.text.trim(),
          'p_landline': _landline.text.trim(),
          'p_email': _email.text.trim(),
          'p_id': widget.existing?['id'],
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.message(e);
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final id = widget.existing?['id'] as String?;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseBootstrap.client.rpc(
        'delete_divisional_organizer',
        params: {'p_id': id},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.message(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? l10n.editOrganizer : l10n.addOrganizer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _dsDivisionId,
              decoration: InputDecoration(labelText: l10n.dsDivision),
              items: [
                for (final d in widget.dsDivisions)
                  DropdownMenuItem(
                    value: d['id'] as int,
                    child: Text(d['name'] as String? ?? ''),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _dsDivisionId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.fullName),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mobile,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.mobile),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _landline,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.landline),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.email),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: SyuColors.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: Text(l10n.removeOrganizer),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
