import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';

class AnnouncementsFeed extends ConsumerStatefulWidget {
  const AnnouncementsFeed({super.key});

  @override
  ConsumerState<AnnouncementsFeed> createState() => _AnnouncementsFeedState();
}

class _AnnouncementsFeedState extends ConsumerState<AnnouncementsFeed> {
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
          .from('announcements')
          .select('id,title,body,published_at')
          .eq('is_published', true)
          .order('published_at', ascending: false)
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

  void _openDetail(Map<String, dynamic> a) {
    final when = a['published_at'] as String?;
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
                  a['title'] as String? ?? '',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                if (when != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    when.split('T').first,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: SyuColors.mist,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  a['body'] as String? ?? '',
                  style: Theme.of(ctx).textTheme.bodyLarge,
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
                      _total == 0 ? 'News' : '$_total news',
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
                                      'No announcements yet.',
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
                                  final a = _items[i];
                                  final when = a['published_at'] as String?;
                                  return ListTile(
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                      horizontal: 0,
                                      vertical: -2,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    minVerticalPadding: 6,
                                    onTap: () => _openDetail(a),
                                    title: Text(
                                      a['title'] as String? ?? '',
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
                                    subtitle: Text(
                                      [
                                        if (when != null) when.split('T').first,
                                        (a['body'] as String? ?? '')
                                            .replaceAll('\n', ' ')
                                            .trim(),
                                      ].where((s) => s.isNotEmpty).join(' · '),
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
