import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// Audience: all | district | ds | gn (not single members).
class AudienceSelection {
  const AudienceSelection({
    this.audience = 'all',
    this.districtId,
    this.dsDivisionId,
    this.gnDivisionId,
  });

  final String audience;
  final int? districtId;
  final int? dsDivisionId;
  final int? gnDivisionId;

  String? validate() {
    switch (audience) {
      case 'district':
        if (districtId == null) return 'Select a district';
      case 'ds':
        if (dsDivisionId == null) return 'Select a DS division';
      case 'gn':
        if (gnDivisionId == null) return 'Select a GN division';
    }
    return null;
  }

  Map<String, dynamic> rpcParams({
    required String titleKey,
    required String bodyKey,
    required String title,
    required String body,
  }) =>
      {
        titleKey: title,
        bodyKey: body,
        'p_audience': audience,
        'p_district_id': audience == 'all' ? null : districtId,
        'p_ds_division_id':
            (audience == 'ds' || audience == 'gn') ? dsDivisionId : null,
        'p_gn_division_id': audience == 'gn' ? gnDivisionId : null,
      };
}

class AdminAudiencePicker extends StatefulWidget {
  const AdminAudiencePicker({
    super.key,
    required this.onChanged,
    this.initial,
  });

  final ValueChanged<AudienceSelection> onChanged;
  final AudienceSelection? initial;

  @override
  State<AdminAudiencePicker> createState() => _AdminAudiencePickerState();
}

class _AdminAudiencePickerState extends State<AdminAudiencePicker> {
  String _audience = 'all';
  int? _districtId;
  int? _dsId;
  int? _gnId;
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _ds = [];
  List<Map<String, dynamic>> _gn = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _audience = widget.initial?.audience ?? 'all';
    _districtId = widget.initial?.districtId;
    _dsId = widget.initial?.dsDivisionId;
    _gnId = widget.initial?.gnDivisionId;
    _boot();
  }

  Future<void> _boot() async {
    try {
      final rows = await SupabaseBootstrap.client
          .from('districts')
          .select('id,name')
          .order('name');
      setState(() {
        _districts = List<Map<String, dynamic>>.from(rows as List);
      });
      if (_districtId != null) await _loadDs(_districtId!);
      if (_dsId != null) await _loadGn(_dsId!);
      _emit();
    } catch (e) {
      AppErrorMapper.log(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDs(int districtId) async {
    final rows = await SupabaseBootstrap.client
        .from('ds_divisions')
        .select('id,name')
        .eq('district_id', districtId)
        .order('name');
    setState(() {
      _ds = List<Map<String, dynamic>>.from(rows as List);
    });
  }

  Future<void> _loadGn(int dsId) async {
    final rows = await SupabaseBootstrap.client
        .from('gn_divisions')
        .select('id,name')
        .eq('ds_division_id', dsId)
        .order('name');
    setState(() {
      _gn = List<Map<String, dynamic>>.from(rows as List);
    });
  }

  void _emit() {
    widget.onChanged(
      AudienceSelection(
        audience: _audience,
        districtId: _districtId,
        dsDivisionId: _dsId,
        gnDivisionId: _gnId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(color: SyuColors.crimson),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Send to', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _audience,
          decoration: const InputDecoration(labelText: 'Audience'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('ALL members')),
            DropdownMenuItem(value: 'district', child: Text('District')),
            DropdownMenuItem(value: 'ds', child: Text('DS division')),
            DropdownMenuItem(value: 'gn', child: Text('GN division')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _audience = v;
              if (v == 'all') {
                _districtId = null;
                _dsId = null;
                _gnId = null;
                _ds = [];
                _gn = [];
              }
            });
            _emit();
          },
        ),
        if (_audience != 'all') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: _districtId,
            decoration: const InputDecoration(labelText: 'District'),
            items: _districts
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as int,
                    child: Text(d['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (id) async {
              setState(() {
                _districtId = id;
                _dsId = null;
                _gnId = null;
                _ds = [];
                _gn = [];
              });
              if (id != null) await _loadDs(id);
              setState(() {});
              _emit();
            },
          ),
        ],
        if (_audience == 'ds' || _audience == 'gn') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: _dsId,
            decoration: const InputDecoration(labelText: 'DS division'),
            items: _ds
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as int,
                    child: Text(d['name'] as String),
                  ),
                )
                .toList(),
            onChanged: _districtId == null
                ? null
                : (id) async {
                    setState(() {
                      _dsId = id;
                      _gnId = null;
                      _gn = [];
                    });
                    if (id != null) await _loadGn(id);
                    setState(() {});
                    _emit();
                  },
          ),
        ],
        if (_audience == 'gn') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: _gnId,
            decoration: const InputDecoration(labelText: 'GN division'),
            items: _gn
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as int,
                    child: Text(d['name'] as String),
                  ),
                )
                .toList(),
            onChanged: _dsId == null
                ? null
                : (id) {
                    setState(() => _gnId = id);
                    _emit();
                  },
          ),
        ],
      ],
    );
  }
}
