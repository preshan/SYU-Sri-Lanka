import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';
import 'package:syu_sri_lanka/features/messaging/data/unread_chats_provider.dart';
import 'package:syu_sri_lanka/features/messaging/presentation/chat_ui.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Admin ↔ member direct chats (no profile images).
class AdminChatPanel extends ConsumerStatefulWidget {
  const AdminChatPanel({
    super.key,
    this.initialMemberId,
    this.initialMemberName,
    this.embedded = false,
  });

  final String? initialMemberId;
  final String? initialMemberName;

  /// When true (bottom nav), show a page title; AdminShell AppBar already titles overlay.
  final bool embedded;

  @override
  ConsumerState<AdminChatPanel> createState() => AdminChatPanelState();
}

class AdminChatPanelState extends ConsumerState<AdminChatPanel> {
  static const _pageSize = 30;

  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  int _page = 0;
  int _total = 0;
  String? _openId;
  String? _openTitle;
  String? _openSubtitle;
  String? _openStatus;

  bool get hasOpenThread => _openId != null;

  int get _totalPages => _total == 0 ? 1 : ((_total - 1) ~/ _pageSize) + 1;

  /// System / gesture back: close open thread. Returns true if consumed.
  bool handleSystemBack() {
    if (_openId == null) return false;
    setState(() {
      _openId = null;
      _openTitle = null;
      _openSubtitle = null;
      _openStatus = null;
    });
    _load(resetPage: true);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _load(resetPage: true);
    if (widget.initialMemberId != null && mounted) {
      await _openWithMember(
        widget.initialMemberId!,
        widget.initialMemberName ?? 'Member',
      );
    }
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() => _loading = true);
    try {
      final res = await SupabaseBootstrap.client.rpc(
        'admin_list_direct_chats',
        params: {
          'p_limit': _pageSize,
          'p_offset': _page * _pageSize,
        },
      );
      final map = res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
      final rawItems = map['items'];
      final list = rawItems is List
          ? List<Map<String, dynamic>>.from(
              rawItems.map((e) => Map<String, dynamic>.from(e as Map)),
            )
          : <Map<String, dynamic>>[];
      final total = map['total'];
      setState(() {
        _chats = list;
        _total = total is int ? total : int.tryParse('$total') ?? list.length;
      });
      await ref.read(unreadChatsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _memberOf(Map<String, dynamic> c) {
    final member = c['member'];
    if (member is Map) return Map<String, dynamic>.from(member);
    return null;
  }

  String _memberTitle(Map<String, dynamic> c, {String fallback = 'Member'}) {
    final member = _memberOf(c);
    final name = (member?['full_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return (c['title'] as String?)?.trim().isNotEmpty == true
        ? c['title'] as String
        : fallback;
  }

  String _memberSubtitle(Map<String, dynamic> c) {
    final member = _memberOf(c);
    return chatPeerMeta(
      email: member?['email'] as String?,
      district: member?['district'] as String?,
    );
  }

  /// Opens existing thread (with history) or creates an empty open chat.
  Future<void> _openWithMember(String memberId, String memberName) async {
    try {
      final res = await SupabaseBootstrap.client.rpc(
        'admin_open_direct_chat',
        params: {'p_member_id': memberId},
      );
      final map = Map<String, dynamic>.from(res as Map);
      await _load(resetPage: true);
      if (!mounted) return;
      final match = _chats.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['id'] == map['conversation_id'],
            orElse: () => null,
          );
      final title = (map['member_name'] as String?)?.trim().isNotEmpty == true
          ? map['member_name'] as String
          : memberName;
      setState(() {
        _openId = map['conversation_id'] as String;
        _openTitle = title;
        _openSubtitle = match != null ? _memberSubtitle(match) : '';
        _openStatus = map['status'] as String? ?? 'open';
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _startWithMember(String memberId, String memberName) async {
    await _openWithMember(memberId, memberName);
  }

  Future<void> _pickMember() async {
    final picked = await showDialog<_MemberPick>(
      context: context,
      builder: (ctx) => const _MemberPickerDialog(),
    );
    if (picked == null || !mounted) return;
    await _startWithMember(picked.id, picked.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_openId != null) {
      return _AdminChatThread(
        conversationId: _openId!,
        title: _openTitle ?? l10n.chat,
        subtitle: _openSubtitle ?? '',
        status: _openStatus ?? 'open',
        onBack: handleSystemBack,
        onClosed: () {
          setState(() => _openStatus = 'closed');
          _load(resetPage: true);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              l10n.chat,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        AdminPanelChrome.toolbar(
          context: context,
          hint: widget.embedded ? l10n.messageMembers : null,
          actions: [
            FilledButton(
              style: AdminPanelChrome.compactFilled,
              onPressed: _pickMember,
              child: Text(l10n.messageAction),
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(resetPage: true),
                  child: _chats.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                'No chats yet — tap Message to start one',
                                style: AdminPanelChrome.hintStyle(context),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: AdminPanelChrome.listPadding,
                          itemCount: _chats.length,
                          separatorBuilder: (_, _) =>
                              AdminPanelChrome.denseDivider(),
                          itemBuilder: (context, i) {
                            final c = _chats[i];
                            final name = _memberTitle(c);
                            final meta = _memberSubtitle(c);
                            final closed = c['status'] == 'closed';
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -2,
                              ),
                              contentPadding: const EdgeInsets.only(right: 0),
                              title: Text(
                                name,
                                style: AdminPanelChrome.rowTitleStyle(context),
                              ),
                              subtitle: Text(
                                [
                                  if (meta.isNotEmpty) meta,
                                  if (closed) 'Terminated',
                                  if ((c['last_message'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    c['last_message'] as String,
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AdminPanelChrome.rowMetaStyle(context),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: SyuColors.mist,
                              ),
                              onTap: () => setState(() {
                                _openId = c['id'] as String;
                                _openTitle = name;
                                _openSubtitle = meta;
                                _openStatus =
                                    c['status'] as String? ?? 'open';
                              }),
                            );
                          },
                        ),
                ),
        ),
        if (!_loading && _total > _pageSize)
          _ChatPaginationBar(
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
    );
  }
}

class _ChatPaginationBar extends StatelessWidget {
  const _ChatPaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = total == 0 ? 0 : ((page + 1) * pageSize).clamp(0, total);
    return Material(
      color: SyuColors.inkElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
                l10n.rangeOf(from, to, total),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                onPressed: onPrev,
                icon: const SyuIcon(SyuIcons.chevronLeft),
                tooltip: 'Previous page',
              ),
              Text(
                l10n.pageLabel(page + 1, totalPages),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                onPressed: onNext,
                icon: const SyuIcon(SyuIcons.chevronRight),
                tooltip: 'Next page',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberPick {
  const _MemberPick(this.id, this.name);
  final String id;
  final String name;
}

class _MemberPickerDialog extends StatefulWidget {
  const _MemberPickerDialog();

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  static const _pageSize = 30;

  final _query = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  int _page = 0;
  int _total = 0;

  int get _totalPages => _total == 0 ? 1 : ((_total - 1) ~/ _pageSize) + 1;

  @override
  void initState() {
    super.initState();
    _search(resetPage: true);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({bool resetPage = false}) async {
    if (resetPage) _page = 0;
    setState(() => _loading = true);
    try {
      final text = _query.text.trim().replaceAll(RegExp(r'[%*,()]'), '');
      var q = SupabaseBootstrap.client
          .from('profiles')
          .select('id,full_name,email')
          .eq('status', 'active');
      if (text.isNotEmpty) {
        final pattern = '%$text%';
        q = q.or('full_name.ilike.$pattern,email.ilike.$pattern');
      }
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      final response = await q
          .order('full_name')
          .range(from, to)
          .count(CountOption.exact);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(response.data as List);
        _total = response.count;
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.selectMember),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _query,
              decoration: InputDecoration(
                hintText: l10n.searchNameOrEmail,
                suffixIcon: IconButton(
                  onPressed: () => _search(resetPage: true),
                  icon: const SyuIcon(SyuIcons.search),
                ),
              ),
              onSubmitted: (_) => _search(resetPage: true),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: SyuColors.crimson),
                    )
                  : _rows.isEmpty
                      ? Center(
                          child: Text(
                            'No members found',
                            style: AdminPanelChrome.hintStyle(context),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final p = _rows[i];
                            final name =
                                (p['full_name'] as String?)?.trim().isNotEmpty ==
                                        true
                                    ? p['full_name'] as String
                                    : (p['email'] as String? ?? 'Member');
                            return ListTile(
                              leading: const SyuIcon(SyuIcons.user),
                              title: Text(name),
                              subtitle: Text(p['email'] as String? ?? ''),
                              onTap: () => Navigator.pop(
                                context,
                                _MemberPick(p['id'] as String, name),
                              ),
                            );
                          },
                        ),
            ),
            if (!_loading && _total > _pageSize)
              Row(
                children: [
                  Text(
                    l10n.rangeOf(
                      _total == 0 ? 0 : _page * _pageSize + 1,
                      ((_page + 1) * _pageSize).clamp(0, _total),
                      _total,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _page <= 0
                        ? null
                        : () async {
                            setState(() => _page -= 1);
                            await _search();
                          },
                    icon: const SyuIcon(SyuIcons.chevronLeft),
                  ),
                  Text(
                    l10n.pageLabel(_page + 1, _totalPages),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    onPressed: _page + 1 >= _totalPages
                        ? null
                        : () async {
                            setState(() => _page += 1);
                            await _search();
                          },
                    icon: const SyuIcon(SyuIcons.chevronRight),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _AdminChatThread extends ConsumerStatefulWidget {
  const _AdminChatThread({
    required this.conversationId,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onBack,
    required this.onClosed,
  });

  final String conversationId;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onBack;
  final VoidCallback onClosed;

  @override
  ConsumerState<_AdminChatThread> createState() => _AdminChatThreadState();
}

class _AdminChatThreadState extends ConsumerState<_AdminChatThread> {
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
          _messages =
              _messages.where((m) => m['id'] != optimistic['id']).toList();
        });
        AppErrorMapper.showSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _terminate() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.terminateChatTitle),
        content: Text(l10n.terminateChatBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.terminate),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseBootstrap.client.rpc(
        'admin_close_conversation',
        params: {'p_conversation_id': widget.conversationId},
      );
      setState(() => _status = 'closed');
      widget.onClosed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatTerminated)),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearChatTitle),
        content: Text(l10n.clearChatBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseBootstrap.client.rpc(
        'admin_clear_conversation',
        params: {'p_conversation_id': widget.conversationId},
      );
      setState(() {
        _status = 'closed';
        _messages = [];
      });
      widget.onClosed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatCleared)),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _reopen() async {
    final l10n = AppLocalizations.of(context);
    try {
      await SupabaseBootstrap.client.rpc(
        'admin_reopen_conversation',
        params: {'p_conversation_id': widget.conversationId},
      );
      setState(() => _status = 'open');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatReopened)),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
    final l10n = AppLocalizations.of(context);
    final open = _status == 'open';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onBack,
                icon: const SyuIcon(SyuIcons.back, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle.isNotEmpty)
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: SyuColors.mist,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      open ? l10n.chatStatusOpen : l10n.chatStatusClosed,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: open ? SyuColors.mist : SyuColors.danger,
                          ),
                    ),
                  ],
                ),
              ),
              if (open) ...[
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: SyuColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: _clear,
                  child: Text(l10n.clear),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _terminate,
                  child: Text(l10n.terminate),
                ),
              ] else
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: _reopen,
                  child: Text(l10n.reopen),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : ChatMessagesView(
                  messages: _messages,
                  currentUserId: uid,
                  peerLastReadAt: _peerLastReadAt,
                  controller: _scroll,
                  compact: true,
                  emptyLabel: open ? l10n.noMessagesYet : l10n.noMessages,
                ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: l10n.messageHint),
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
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.chatClosedHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: SyuColors.mist),
            ),
          ),
      ],
    );
  }
}
