import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  static const _pageSize = AdminPanelChrome.pageSize;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  int _total = 0;

  int get _totalPages => AdminPanelChrome.totalPages(_total, _pageSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      final response = await SupabaseBootstrap.client
          .from('events')
          .select('id,title,description,starts_at,location_text')
          .eq('is_published', true)
          .order('starts_at')
          .range(from, to)
          .count(CountOption.exact);
      setState(() {
        _items = List<Map<String, dynamic>>.from(response.data as List);
        _total = response.count;
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

  void _openDetail(Map<String, dynamic> e) {
    final id = e['id'] as String;
    final when = (e['starts_at'] as String?)?.split('T').first;
    final location = e['location_text'] as String?;
    final description = e['description'] as String?;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['title'] as String? ?? '',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                if (when != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: SyuColors.mist,
                        ),
                  ),
                ],
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description, style: Theme.of(ctx).textTheme.bodyLarge),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _rsvp(id);
                    },
                    child: const Text('RSVP Going'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SyuGradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _total == 0 ? 'Events' : '$_total events',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: SyuColors.mist,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: SyuColors.crimson,
                onRefresh: () => _load(),
                child: _loading && _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: CircularProgressIndicator(
                              color: SyuColors.crimson,
                            ),
                          ),
                        ],
                      )
                    : _error != null
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(14),
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(color: SyuColors.danger),
                              ),
                            ],
                          )
                        : _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 40),
                                  Center(
                                    child: Text(
                                      'No published events yet.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: SyuColors.mist),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                                itemCount: _items.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: SyuColors.border,
                                ),
                                itemBuilder: (context, i) {
                                  final e = _items[i];
                                  final id = e['id'] as String;
                                  final when = (e['starts_at'] as String?)
                                      ?.split('T')
                                      .first;
                                  final location =
                                      e['location_text'] as String?;
                                  final meta = [
                                    ?when,
                                    if (location != null && location.isNotEmpty)
                                      location,
                                  ].join(' · ');
                                  return ListTile(
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                      horizontal: 0,
                                      vertical: -2,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    minVerticalPadding: 6,
                                    onTap: () => _openDetail(e),
                                    title: Text(
                                      e['title'] as String? ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                    ),
                                    subtitle: meta.isEmpty
                                        ? null
                                        : Text(
                                            meta,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: SyuColors.mist,
                                                  height: 1.3,
                                                ),
                                          ),
                                    trailing: TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => _rsvp(id),
                                      child: const Text('RSVP'),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            AdminPaginationBar(
              page: _page,
              totalPages: _totalPages,
              total: _total,
              pageSize: _pageSize,
              onPrev: _page <= 0
                  ? null
                  : () async {
                      setState(() => _page -= 1);
                      await _load();
                    },
              onNext: _page + 1 >= _totalPages
                  ? null
                  : () async {
                      setState(() => _page += 1);
                      await _load();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
