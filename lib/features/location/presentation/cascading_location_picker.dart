import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

class District {
  District({required this.id, required this.name, this.province});
  final int id;
  final String name;
  final String? province;
}

class DsDivision {
  DsDivision({required this.id, required this.districtId, required this.name});
  final int id;
  final int districtId;
  final String name;
}

class GnDivision {
  GnDivision({required this.id, required this.dsDivisionId, required this.name});
  final int id;
  final int dsDivisionId;
  final String name;
}

class LocationSelection {
  const LocationSelection({
    this.districtId,
    this.dsDivisionId,
    this.gnDivisionId,
  });

  final int? districtId;
  final int? dsDivisionId;
  final int? gnDivisionId;
}

class CascadingLocationPicker extends ConsumerStatefulWidget {
  const CascadingLocationPicker({
    super.key,
    required this.onChanged,
    this.initial,
  });

  final ValueChanged<LocationSelection> onChanged;
  final LocationSelection? initial;

  @override
  ConsumerState<CascadingLocationPicker> createState() =>
      _CascadingLocationPickerState();
}

class _CascadingLocationPickerState
    extends ConsumerState<CascadingLocationPicker> {
  List<District> _districts = [];
  List<DsDivision> _ds = [];
  List<GnDivision> _gn = [];
  int? _districtId;
  int? _dsId;
  int? _gnId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _districtId = widget.initial?.districtId;
    _dsId = widget.initial?.dsDivisionId;
    _gnId = widget.initial?.gnDivisionId;
    _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseBootstrap.client
          .from('districts')
          .select('id,name,province')
          .order('name');
      _districts = (rows as List)
          .map(
            (r) => District(
              id: r['id'] as int,
              name: r['name'] as String,
              province: r['province'] as String?,
            ),
          )
          .toList();
      if (_districtId != null) await _loadDs(_districtId!);
      if (_dsId != null) await _loadGn(_dsId!);
    } catch (e) {
      _error = 'Could not load locations';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDs(int districtId) async {
    final rows = await SupabaseBootstrap.client
        .from('ds_divisions')
        .select('id,district_id,name')
        .eq('district_id', districtId)
        .order('name');
    _ds = (rows as List)
        .map(
          (r) => DsDivision(
            id: r['id'] as int,
            districtId: r['district_id'] as int,
            name: r['name'] as String,
          ),
        )
        .toList();
  }

  Future<void> _loadGn(int dsId) async {
    final rows = await SupabaseBootstrap.client
        .from('gn_divisions')
        .select('id,ds_division_id,name')
        .eq('ds_division_id', dsId)
        .order('name');
    _gn = (rows as List)
        .map(
          (r) => GnDivision(
            id: r['id'] as int,
            dsDivisionId: r['ds_division_id'] as int,
            name: r['name'] as String,
          ),
        )
        .toList();
  }

  void _emit() {
    widget.onChanged(
      LocationSelection(
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
        child: Center(child: CircularProgressIndicator(color: SyuColors.crimson)),
      );
    }
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: SyuColors.danger));
    }

    return Column(
      children: [
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _districtId,
          decoration: const InputDecoration(labelText: 'District'),
          items: _districts
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(d.name),
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
            if (id != null) {
              await _loadDs(id);
              setState(() {});
            }
            _emit();
          },
          validator: (v) => v == null ? 'Select a district' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _dsId,
          decoration: const InputDecoration(labelText: 'DS Division'),
          items: _ds
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
              .toList(),
          onChanged: _districtId == null
              ? null
              : (id) async {
                  setState(() {
                    _dsId = id;
                    _gnId = null;
                    _gn = [];
                  });
                  if (id != null) {
                    await _loadGn(id);
                    setState(() {});
                  }
                  _emit();
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _gnId,
          decoration: const InputDecoration(labelText: 'GN Division (optional)'),
          items: _gn
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
              .toList(),
          onChanged: _dsId == null
              ? null
              : (id) {
                  setState(() => _gnId = id);
                  _emit();
                },
        ),
      ],
    );
  }
}
