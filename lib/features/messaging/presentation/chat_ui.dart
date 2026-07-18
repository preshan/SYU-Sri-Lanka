import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// Formats `email | District` for chat headers / list subtitles.
String chatPeerMeta({String? email, String? district}) {
  final parts = <String>[
    if (email != null && email.trim().isNotEmpty) email.trim(),
    if (district != null && district.trim().isNotEmpty) district.trim(),
  ];
  return parts.join(' | ');
}

DateTime? parseChatTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc();
}

bool messageIsSeen({
  required DateTime? messageCreatedAt,
  required DateTime? peerLastReadAt,
}) {
  if (messageCreatedAt == null || peerLastReadAt == null) return false;
  return !peerLastReadAt.isBefore(messageCreatedAt);
}

DateTime _dayKey(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// WhatsApp-style day label for a message timestamp.
String chatDayLabel(DateTime createdAt) {
  final day = _dayKey(createdAt);
  final today = _dayKey(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  if (day.year == today.year) {
    return DateFormat('EEE, d MMM').format(day);
  }
  return DateFormat('d MMM yyyy').format(day);
}

/// Outgoing/incoming bubble with optional small seen tick (no sent icon).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.body,
    required this.mine,
    this.seen = false,
    this.compact = false,
  });

  final String body;
  final bool mine;
  final bool seen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 12.0 : 14.0;
    final padH = compact ? 12.0 : 14.0;
    final padV = compact ? 8.0 : 10.0;
    final fontSize = compact ? 13.0 : 14.0;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: compact ? 6 : 8),
        padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (compact ? 0.72 : 0.75),
        ),
        decoration: BoxDecoration(
          color: mine
              ? SyuColors.crimson.withValues(alpha: 0.9)
              : SyuColors.inkSoft,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              style: TextStyle(
                fontSize: fontSize,
                color: mine ? SyuColors.paper : SyuColors.ink,
              ),
            ),
            if (mine && seen) ...[
              const SizedBox(height: 3),
              Icon(
                Icons.done_all,
                size: compact ? 12 : 13,
                color: SyuColors.paper.withValues(alpha: 0.85),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatDayChip extends StatelessWidget {
  const _ChatDayChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SyuColors.inkSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SyuColors.border),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SyuColors.mist,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp-style thread: anchored to bottom, day separators, reverse load.
class ChatMessagesView extends StatelessWidget {
  const ChatMessagesView({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.peerLastReadAt,
    this.compact = false,
    this.controller,
    this.emptyLabel,
  });

  /// Chronological oldest → newest.
  final List<Map<String, dynamic>> messages;
  final String? currentUserId;
  final DateTime? peerLastReadAt;
  final bool compact;
  final ScrollController? controller;
  final String? emptyLabel;

  List<Widget> _buildReversedItems() {
    // Build oldest→newest with day headers, then reverse so index 0 is newest
    // (bottom of a reverse ListView).
    final chron = <Widget>[];
    DateTime? lastDay;
    for (final m in messages) {
      final created = parseChatTimestamp(m['created_at']) ?? DateTime.now();
      final day = _dayKey(created);
      if (lastDay == null || day != lastDay) {
        chron.add(_ChatDayChip(chatDayLabel(created)));
        lastDay = day;
      }
      final mine = m['sender_id'] == currentUserId;
      final seen = mine &&
          messageIsSeen(
            messageCreatedAt: created,
            peerLastReadAt: peerLastReadAt,
          );
      chron.add(
        ChatBubble(
          body: m['body'] as String? ?? '',
          mine: mine,
          seen: seen,
          compact: compact,
        ),
      );
    }
    return chron.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          emptyLabel ?? 'No messages yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SyuColors.mist,
              ),
        ),
      );
    }

    final items = _buildReversedItems();
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        8,
        compact ? 12 : 16,
        8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }
}
