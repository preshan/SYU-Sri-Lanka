import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/features/auth/data/auth_repository.dart';

/// True when the signed-in user has at least one unread message from someone else.
final unreadChatsProvider =
    StateNotifierProvider<UnreadChatsController, bool>((ref) {
  final controller = UnreadChatsController();
  ref.listen(currentSessionProvider, (prev, next) {
    controller.onSessionChanged(next?.user.id);
  });
  ref.onDispose(controller.dispose);
  controller.onSessionChanged(
    ref.read(currentSessionProvider)?.user.id,
  );
  return controller;
});

class UnreadChatsController extends StateNotifier<bool> {
  UnreadChatsController() : super(false);

  RealtimeChannel? _channel;
  Timer? _poll;
  String? _userId;

  void onSessionChanged(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _teardown();
    if (userId == null) {
      state = false;
      return;
    }
    refresh();
    _subscribe(userId);
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => refresh());
  }

  Future<void> refresh() async {
    if (_userId == null) {
      state = false;
      return;
    }
    try {
      final res = await SupabaseBootstrap.client.rpc('has_unread_chats');
      if (mounted) state = res == true;
    } catch (e) {
      AppErrorMapper.log(e);
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    try {
      await SupabaseBootstrap.client.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
      await refresh();
    } catch (e) {
      AppErrorMapper.log(e);
    }
  }

  void _subscribe(String userId) {
    _channel = SupabaseBootstrap.client
        .channel('unread-chats-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final row = payload.newRecord;
            final sender = row['sender_id'] as String?;
            if (sender != null && sender != userId) {
              // New message from someone else — cheap optimistic flag, then verify.
              state = true;
              refresh();
            }
          },
        )
        .subscribe();
  }

  void _teardown() {
    _poll?.cancel();
    _poll = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      unawaited(SupabaseBootstrap.client.removeChannel(ch));
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
