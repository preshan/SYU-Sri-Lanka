import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/messaging/data/unread_chats_provider.dart';
import 'package:syu_sri_lanka/features/messaging/presentation/chat_ui.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({
    super.key,
    this.active = true,
    this.embedInHomeShell = false,
  });

  /// When false (other bottom-nav tabs), skip auto-refresh.
  final bool active;

  /// When true, [HomeShell] owns system-back; when false (e.g. `/messages`), handle locally.
  final bool embedInHomeShell;

  @override
  ConversationsListScreenState createState() => ConversationsListScreenState();
}

class ConversationsListScreenState
    extends ConsumerState<ConversationsListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _openId;
  String? _openTitle;
  String? _openSubtitle;
  String? _openStatus;

  bool get hasOpenThread => _openId != null;

  /// System / gesture back: close open thread. Returns true if consumed.
  bool handleSystemBack() {
    if (_openId == null) return false;
    setState(() {
      _openId = null;
      _openTitle = null;
      _openSubtitle = null;
      _openStatus = null;
    });
    _load();
    return true;
  }

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

  Map<String, dynamic>? _peerOf(Map<String, dynamic> c) {
    final peer = c['peer'];
    if (peer is Map) return Map<String, dynamic>.from(peer);
    return null;
  }

  String _displayTitle(Map<String, dynamic> c) {
    if (c['type'] == 'direct') return 'SYU Admin';
    final title = c['title'] as String?;
    if (title != null && title.isNotEmpty) return title;
    return c['type'] as String? ?? 'Chat';
  }

  String _displaySubtitle(Map<String, dynamic> c) {
    final peer = _peerOf(c);
    return chatPeerMeta(
      email: peer?['email'] as String?,
      district: peer?['district'] as String?,
    );
  }

  void _openChat(Map<String, dynamic> c) {
    setState(() {
      _openId = c['id'] as String;
      _openTitle = _displayTitle(c);
      _openSubtitle = _displaySubtitle(c);
      _openStatus = c['status'] as String? ?? 'open';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = _openId != null
        ? _ChatThread(
            conversationId: _openId!,
            title: _openTitle ?? l10n.chat,
            subtitle: _openSubtitle ?? '',
            status: _openStatus ?? 'open',
            onBack: handleSystemBack,
          )
        : SyuGradientBackground(
            child: SafeArea(
              child: RefreshIndicator(
                color: SyuColors.crimson,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      children: [
                        if (context.canPop())
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const SyuIcon(SyuIcons.back),
                          ),
                        Expanded(
                          child: Text(
                            l10n.chat,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.chatListSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: SyuColors.crimson,
                          ),
                        ),
                      )
                    else if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: SyuColors.danger),
                      )
                    else if (_items.isEmpty)
                      Text(
                        l10n.noConversationsYet,
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    else
                      ..._items.map((c) {
                        final closed = c['status'] == 'closed';
                        final subtitle = _displaySubtitle(c);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _openChat(c),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: SyuColors.inkElevated
                                      .withValues(alpha: 0.9),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _displayTitle(c),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          if (subtitle.isNotEmpty)
                                            Text(
                                              subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: SyuColors.mist,
                                                    fontSize: 11,
                                                  ),
                                            ),
                                          if (closed)
                                            Text(
                                              'Chat ended',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: SyuColors.mist,
                                                  ),
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
                                                  ?.copyWith(
                                                    color: SyuColors.mist,
                                                  ),
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

    if (widget.embedInHomeShell) return body;
    return SyuBackScope(
      onBack: handleSystemBack,
      fallbackLocation: '/home',
      child: body,
    );
  }
}

class _ChatThread extends ConsumerStatefulWidget {
  const _ChatThread({
    required this.conversationId,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onBack,
  });

  final String conversationId;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onBack;

  @override
  ConsumerState<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<_ChatThread> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  DateTime? _peerLastReadAt;
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

  void _scrollToBottom({bool animated = false}) {
    // reverse:true ListView — offset 0 is the newest messages (bottom).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animated) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(0);
      }
    });
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      final rows = await SupabaseBootstrap.client
          .from('messages')
          .select('id,body,sender_id,created_at')
          .eq('conversation_id', widget.conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true)
          .limit(200);

      var status = _status;
      try {
        final conv = await SupabaseBootstrap.client
            .from('conversations')
            .select('status')
            .eq('id', widget.conversationId)
            .maybeSingle();
        if (conv != null) {
          status = conv['status'] as String? ?? status;
        }
      } catch (e) {
        AppErrorMapper.log(e);
      }

      DateTime? peerRead = _peerLastReadAt;
      if (uid != null) {
        try {
          final peers = await SupabaseBootstrap.client
              .from('conversation_participants')
              .select('last_read_at,user_id')
              .eq('conversation_id', widget.conversationId)
              .neq('user_id', uid)
              .limit(1);
          final peerRows = List<Map<String, dynamic>>.from(peers as List);
          if (peerRows.isNotEmpty) {
            peerRead = parseChatTimestamp(peerRows.first['last_read_at']);
          }
        } catch (e) {
          AppErrorMapper.log(e);
        }
      }

      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows as List);
        _peerLastReadAt = peerRead;
        _status = status;
        _loading = false;
      });
      _scrollToBottom();

      try {
        await ref
            .read(unreadChatsProvider.notifier)
            .markConversationRead(widget.conversationId);
      } catch (e) {
        AppErrorMapper.log(e);
      }
    } catch (e) {
      AppErrorMapper.log(e);
      if (mounted) {
        setState(() => _loading = false);
        AppErrorMapper.showSnackBar(context, e);
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _status != 'open') return;
    setState(() => _sending = true);
    final uid = SupabaseBootstrap.client.auth.currentUser!.id;
    final optimistic = <String, dynamic>{
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'body': text,
      'sender_id': uid,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _messages = [..._messages, optimistic];
    });
    _controller.clear();
    _scrollToBottom(animated: true);
    try {
      await SupabaseBootstrap.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': uid,
        'body': text,
      });
      await _load();
      _scrollToBottom(animated: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m['id'] != optimistic['id']).toList();
        });
        AppErrorMapper.showSnackBar(context, e);
      }
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
                        if (widget.subtitle.isNotEmpty)
                          Text(
                            widget.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: SyuColors.mist,
                                  fontSize: 11,
                                ),
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
                  : ChatMessagesView(
                      messages: _messages,
                      currentUserId: uid,
                      peerLastReadAt: _peerLastReadAt,
                      controller: _scroll,
                      emptyLabel: open
                          ? 'No messages yet — write below'
                          : 'No messages',
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
                  'This chat was ended.',
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
