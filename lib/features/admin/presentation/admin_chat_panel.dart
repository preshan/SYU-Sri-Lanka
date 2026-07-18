import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';
import 'package:syu_sri_lanka/features/messaging/data/unread_chats_provider.dart';

/// Admin ↔ member direct chats (no profile images).
class AdminChatPanel extends ConsumerStatefulWidget {
  const AdminChatPanel({super.key, this.initialMemberId, this.initialMemberName});

  final String? initialMemberId;
  final String? initialMemberName;

  @override
  ConsumerState<AdminChatPanel> createState() => _AdminChatPanelState();
}

class _AdminChatPanelState extends ConsumerState<AdminChatPanel> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String? _openId;
  String? _openTitle;
  String? _openStatus;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _load();
    if (widget.initialMemberId != null && mounted) {
      await _openWithMember(
        widget.initialMemberId!,
        widget.initialMemberName ?? 'Member',
      );
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseBootstrap.client.rpc('admin_list_direct_chats');
      final list = res is List
          ? List<Map<String, dynamic>>.from(
              res.map((e) => Map<String, dynamic>.from(e as Map)),
            )
          : <Map<String, dynamic>>[];
      setState(() => _chats = list);
      await ref.read(unreadChatsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens existing thread (with history) or creates an empty open chat.
  Future<void> _openWithMember(String memberId, String memberName) async {
    try {
      final res = await SupabaseBootstrap.client.rpc(
        'admin_open_direct_chat',
        params: {'p_member_id': memberId},
      );
      final map = Map<String, dynamic>.from(res as Map);
      await _load();
      if (!mounted) return;
      setState(() {
        _openId = map['conversation_id'] as String;
        _openTitle = (map['member_name'] as String?)?.trim().isNotEmpty == true
            ? map['member_name'] as String
            : memberName;
        _openStatus = map['status'] as String? ?? 'open';
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _startWithMember(String memberId, String memberName) async {
    // From "Message" picker: open history thread directly (no first-message dialog).
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
    if (_openId != null) {
      return _AdminChatThread(
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
        onClosed: () {
          setState(() => _openStatus = 'closed');
          _load();
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelChrome.toolbar(
          context: context,
          actions: [
            FilledButton(
              style: AdminPanelChrome.compactFilled,
              onPressed: _pickMember,
              child: const Text('Message'),
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _chats.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                'No member chats yet',
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
                            final member = c['member'] is Map
                                ? Map<String, dynamic>.from(c['member'] as Map)
                                : null;
                            final name = (member?['full_name'] as String?)
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? member!['full_name'] as String
                                : (c['title'] as String? ?? 'Member');
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
                                  if (closed) 'Terminated',
                                  if ((c['last_message'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    c['last_message'] as String,
                                ].join(' · '),
                                maxLines: 1,
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
                                _openStatus = c['status'] as String? ?? 'open';
                              }),
                            );
                          },
                        ),
                ),
        ),
      ],
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
  final _query = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final text = _query.text.trim();
      dynamic q = SupabaseBootstrap.client
          .from('profiles')
          .select('id,full_name,email')
          .eq('status', 'active');
      if (text.isNotEmpty) {
        q = q.or('full_name.ilike.%$text%,email.ilike.%$text%');
      }
      final rows = await q.order('full_name').limit(40);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select member'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _query,
              decoration: InputDecoration(
                hintText: 'Search name or email',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const SyuIcon(SyuIcons.search),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: SyuColors.crimson),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final p = _rows[i];
                        final name = (p['full_name'] as String?)?.trim().isNotEmpty ==
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _AdminChatThread extends ConsumerStatefulWidget {
  const _AdminChatThread({
    required this.conversationId,
    required this.title,
    required this.status,
    required this.onBack,
    required this.onClosed,
  });

  final String conversationId;
  final String title;
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

  Future<void> _terminate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminate chat?'),
        content: const Text(
          'The member will no longer be able to reply. Messages stay visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminate'),
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
          const SnackBar(content: Text('Chat terminated')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all messages?'),
        content: const Text(
          'Deletes every message in this chat and closes it. '
          'The member will no longer be able to reply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
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
          const SnackBar(content: Text('Chat cleared')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  Future<void> _reopen() async {
    try {
      await SupabaseBootstrap.client.rpc(
        'admin_reopen_conversation',
        params: {'p_conversation_id': widget.conversationId},
      );
      setState(() => _status = 'open');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat reopened')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseBootstrap.client.auth.currentUser?.id;
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
                    Text(
                      open ? 'Open — can reply' : 'Closed — member cannot reply',
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
                  child: const Text('Clear'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _terminate,
                  child: const Text('Terminate'),
                ),
              ] else
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: _reopen,
                  child: const Text('Reopen'),
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
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        open ? 'No messages yet — write below' : 'No messages',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: SyuColors.mist,
                            ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m['sender_id'] == uid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.sizeOf(context).width * 0.72,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? SyuColors.crimson.withValues(alpha: 0.9)
                                  : SyuColors.inkSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              m['body'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 13,
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
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Message…'),
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
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'This chat is closed. The member cannot reply. Tap Reopen to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SyuColors.mist),
            ),
          ),
      ],
    );
  }
}
