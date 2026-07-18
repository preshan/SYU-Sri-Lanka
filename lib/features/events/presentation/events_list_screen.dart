import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
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
      final rows = await SupabaseBootstrap.client
          .from('events')
          .select('id,title,description,starts_at,location_text')
          .eq('is_published', true)
          .order('starts_at')
          .limit(50);
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

  Future<void> _rsvp(String eventId) async {
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return;
      await SupabaseBootstrap.client.from('event_rsvps').upsert({
        'event_id': eventId,
        'profile_id': uid,
        'status': 'going',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RSVP saved as Going')),
      );
    } catch (e) {
      if (!mounted) return;
      AppErrorMapper.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SyuGradientBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: SyuColors.crimson,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text('Events', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Discover and RSVP to SYU events.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
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
                  'No published events yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                ..._items.map((e) {
                  final id = e['id'] as String;
                  final when = (e['starts_at'] as String?)?.split('T').first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: SyuColors.inkElevated.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['title'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (when != null) ...[
                            const SizedBox(height: 4),
                            Text(when,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                          if ((e['location_text'] as String?)?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 4),
                            Text(
                              e['location_text'] as String,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          if ((e['description'] as String?)?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 10),
                            Text(
                              e['description'] as String,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () => _rsvp(id),
                              child: const Text('RSVP Going'),
                            ),
                          ),
                        ],
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
