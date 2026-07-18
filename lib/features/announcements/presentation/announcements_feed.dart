import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';

class AnnouncementsFeed extends ConsumerStatefulWidget {
  const AnnouncementsFeed({super.key});

  @override
  ConsumerState<AnnouncementsFeed> createState() => _AnnouncementsFeedState();
}

class _AnnouncementsFeedState extends ConsumerState<AnnouncementsFeed> {
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
          .from('announcements')
          .select('id,title,body,published_at')
          .eq('is_published', true)
          .order('published_at', ascending: false)
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
              Text(
                'Announcements',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Organization and club updates.',
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
                  'No announcements yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                ..._items.map((a) {
                  final when = a['published_at'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: SyuColors.inkElevated.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: SyuColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (when != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              when.split('T').first,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            a['body'] as String? ?? '',
                            style: Theme.of(context).textTheme.bodyLarge,
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
