import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

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
      final parts = await SupabaseBootstrap.client
          .from('conversation_participants')
          .select('conversation_id, conversations(id,title,type,updated_at)')
          .eq('user_id', uid)
          .order('joined_at', ascending: false);
      final mapped = <Map<String, dynamic>>[];
      for (final row in parts as List) {
        final c = row['conversations'];
        if (c is Map<String, dynamic>) mapped.add(c);
      }
      setState(() => _items = mapped);
    } catch (e) {
      AppErrorMapper.log(e);
      setState(() => _error = AppErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_openId != null) {
      return _ChatThread(
        conversationId: _openId!,
        onBack: () {
          setState(() => _openId = null);
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
                'Club and direct conversations.',
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
                  'No conversations yet. Admins can add you to a club chat.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                ..._items.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            setState(() => _openId = c['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color:
                                SyuColors.inkElevated.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            border:
                                Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline,
                                  color: SyuColors.crimsonSoft),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  (c['title'] as String?)?.isNotEmpty == true
                                      ? c['title'] as String
                                      : (c['type'] as String? ?? 'Chat'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: SyuColors.mist),
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

class _ChatThread extends StatefulWidget {
  const _ChatThread({required this.conversationId, required this.onBack});

  final String conversationId;
  final VoidCallback onBack;

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<_ChatThread> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows as List);
      });
    } catch (e) {
      AppErrorMapper.log(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
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
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text('Chat', style: Theme.of(context).textTheme.titleLarge),
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
                                  ? SyuColors.crimson.withValues(alpha: 0.85)
                                  : SyuColors.inkElevated,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              m['body'] as String? ?? '',
                              style: TextStyle(
                                color: mine ? SyuColors.paper : SyuColors.mist,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                      ),
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
