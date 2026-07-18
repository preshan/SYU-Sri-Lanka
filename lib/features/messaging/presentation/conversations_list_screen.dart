import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/messaging/data/unread_chats_provider.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key, this.active = true});

  /// When false (other bottom-nav tabs), skip auto-refresh.
  final bool active;

  @override
  ConsumerState<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState
    extends ConsumerState<ConversationsListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _openId;
  String? _openTitle;
  String? _openStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConversationsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _openId == null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return;
      final res = await SupabaseBootstrap.client.rpc('member_list_conversations');
      final list = res is List
          ? List<Map<String, dynamic>>.from(
              res.map((e) => Map<String, dynamic>.from(e as Map)),
            )
          : <Map<String, dynamic>>[];
      setState(() => _items = list);
    } catch (e) {
      AppErrorMapper.log(e);
      setState(() => _error = AppErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayTitle(Map<String, dynamic> c) {
    if (c['type'] == 'direct') return 'SYU Admin';
    final title = c['title'] as String?;
    if (title != null && title.isNotEmpty) return title;
    return c['type'] as String? ?? 'Chat';
  }

  @override
  Widget build(BuildContext context) {
    if (_openId != null) {
      return _ChatThread(
        conversationId: _openId!,
        title: _openTitle ?? 'Chat',
        status: _openStatus ?? 'open',
        onBack: () {
          setState(() {
            _openId = null;
            _openTitle = null;
            _openStatus = null;
          });
          _load();
        },
      );
    }

    return SyuGradientBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: SyuColors.crimson,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                'Messages',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Chats with SYU admins and clubs.',
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
                  'No conversations yet. When an admin messages you, it will appear here.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                ..._items.map((c) {
                  final closed = c['status'] == 'closed';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() {
                          _openId = c['id'] as String;
                          _openTitle = _displayTitle(c);
                          _openStatus = c['status'] as String? ?? 'open';
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color:
                                SyuColors.inkElevated.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: SyuColors.border),
                          ),
                          child: Row(
                            children: [
                              SyuIcon(
                                closed ? SyuIcons.lock : SyuIcons.chat,
                                color: SyuColors.crimsonSoft,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayTitle(c),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (closed)
                                      Text(
                                        'Chat ended',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: SyuColors.mist),
                                      )
                                    else if ((c['last_message'] as String?)
                                            ?.isNotEmpty ==
                                        true)
                                      Text(
                                        c['last_message'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: SyuColors.mist),
                                      ),
                                  ],
                                ),
                              ),
                              const SyuIcon(
                                SyuIcons.chevronRight,
                                color: SyuColors.mist,
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

class _ChatThread extends ConsumerStatefulWidget {
  const _ChatThread({
    required this.conversationId,
    required this.title,
    required this.status,
    required this.onBack,
  });

  final String conversationId;
  final String title;
  final String status;
  final VoidCallback onBack;

  @override
  ConsumerState<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<_ChatThread> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseBootstrap.client
          .from('messages')
          .select('id,body,sender_id,created_at')
          .eq('conversation_id', widget.conversationId)
          .isFilter('deleted_at', null)
          .order('created_at')
          .limit(200);
      final conv = await SupabaseBootstrap.client
          .from('conversations')
          .select('status')
          .eq('id', widget.conversationId)
          .maybeSingle();
      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows as List);
        if (conv != null) _status = conv['status'] as String? ?? _status;
      });
      await ref
          .read(unreadChatsProvider.notifier)
          .markConversationRead(widget.conversationId);
    } catch (e) {
      AppErrorMapper.log(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _status != 'open') return;
    setState(() => _sending = true);
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser!.id;
      await SupabaseBootstrap.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': uid,
        'body': text,
      });
      _controller.clear();
      await _load();
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    final open = _status == 'open';
    return SyuGradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const SyuIcon(SyuIcons.back),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (!open)
                          Text(
                            'This chat was ended by an admin',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: SyuColors.mist),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: SyuColors.crimson),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m['sender_id'] == uid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.sizeOf(context).width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? SyuColors.crimson.withValues(alpha: 0.9)
                                  : SyuColors.inkSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              m['body'] as String? ?? '',
                              style: TextStyle(
                                color: mine ? SyuColors.paper : SyuColors.ink,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Reply…',
                        ),
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const SyuIcon(SyuIcons.send),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'You can no longer reply — this chat was terminated.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SyuColors.mist,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
