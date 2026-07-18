import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

class AdminMembersPanel extends StatefulWidget {
  const AdminMembersPanel({super.key});

  @override
  State<AdminMembersPanel> createState() => _AdminMembersPanelState();
}

class _AdminMembersPanelState extends State<AdminMembersPanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = SupabaseBootstrap.client
          .from('profiles')
          .select('id,full_name,email,phone,status,created_at');
      if (_status != 'all') {
        q = q.eq('status', _status);
      }
      final rows = await q.order('created_at', ascending: false).limit(200);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('Members', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(
                    value: 'pending_registration',
                    child: Text('Incomplete'),
                  ),
                  DropdownMenuItem(
                    value: 'pending_approval',
                    child: Text('Pending'),
                  ),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                    value: 'suspended',
                    child: Text('Suspended'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _status = v);
                  _load();
                },
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
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _rows[i];
                      return Card(
                        child: ListTile(
                          title: Text(p['full_name'] as String? ?? 'Unnamed'),
                          subtitle: Text(
                            '${p['email'] ?? ''}\n${p['status']}',
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
                                value: 'pending_approval',
                                child: Text('Set pending'),
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
      ],
    );
  }
}
