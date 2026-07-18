import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';

class AdminClubsPanel extends StatefulWidget {
  const AdminClubsPanel({super.key});

  @override
  State<AdminClubsPanel> createState() => _AdminClubsPanelState();
}

class _AdminClubsPanelState extends State<AdminClubsPanel> {
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
          .from('youth_clubs')
          .select('id,code,name,district_id,is_active')
          .order('name');
      setState(() => _rows = List<Map<String, dynamic>>.from(rows as List));
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String id, bool active) async {
    try {
      await SupabaseBootstrap.client
          .from('youth_clubs')
          .update({'is_active': active}).eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _create() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New youth club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseBootstrap.client.from('youth_clubs').insert({
        'code': code.text.trim(),
        'name': name.text.trim(),
        'is_active': true,
      });
      await _load();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminPanelChrome.toolbar(
          context: context,
          hint: 'Toggle active clubs',
          actions: [
            FilledButton.icon(
              style: AdminPanelChrome.compactFilled,
              onPressed: _create,
              icon: const SyuIcon(SyuIcons.add, size: 16, color: SyuColors.paper),
              label: const Text('Add'),
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _rows.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                'No clubs yet',
                                style: AdminPanelChrome.hintStyle(context),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: AdminPanelChrome.listPadding,
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) =>
                              AdminPanelChrome.denseDivider(),
                          itemBuilder: (context, i) {
                            final c = _rows[i];
                            final active = c['is_active'] == true;
                            return SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -2,
                              ),
                              title: Text(
                                c['name'] as String? ?? '',
                                style: AdminPanelChrome.rowTitleStyle(context),
                              ),
                              subtitle: Text(
                                c['code'] as String? ?? '',
                                style: AdminPanelChrome.rowMetaStyle(context),
                              ),
                              value: active,
                              onChanged: (v) => _toggle(c['id'] as String, v),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
