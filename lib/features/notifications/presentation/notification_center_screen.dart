import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await SupabaseBootstrap.client
          .from('notifications')
          .select('id,title,body,type,read_at,created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100);
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows as List);
      });
    } catch (e) {
      AppErrorMapper.log(e);
      setState(() => _error = AppErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await SupabaseBootstrap.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SyuGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Notifications')),
        body: RefreshIndicator(
          color: SyuColors.crimson,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: SyuColors.crimson),
                  ),
                )
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: SyuColors.danger))
              else if (_items.isEmpty)
                Text(
                  'No notifications yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                ..._items.map((n) {
                  final unread = n['read_at'] == null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _markRead(n['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                SyuColors.inkElevated.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: unread
                                  ? SyuColors.crimson.withValues(alpha: 0.5)
                                  : SyuColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['title'] as String? ?? '',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n['body'] as String? ?? '',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
