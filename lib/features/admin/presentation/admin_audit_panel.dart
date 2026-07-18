import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

class AdminAuditPanel extends StatefulWidget {
  const AdminAuditPanel({super.key});

  @override
  State<AdminAuditPanel> createState() => _AdminAuditPanelState();
}

class _AdminAuditPanelState extends State<AdminAuditPanel> {
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
          .from('activity_logs')
          .select('id,action,entity_type,entity_id,metadata,created_at,actor_id')
          .order('created_at', ascending: false)
          .limit(100);
      setState(() => _rows = List<Map<String, dynamic>>.from(rows as List));
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
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
    if (_rows.isEmpty) {
      return const Center(child: Text('No audit events yet'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final a = _rows[i];
          final when = (a['created_at'] as String?)?.split('T').first ?? '';
          return Card(
            child: ListTile(
              title: Text(a['action'] as String? ?? ''),
              subtitle: Text(
                '${a['entity_type']} · $when\n${a['metadata']}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
