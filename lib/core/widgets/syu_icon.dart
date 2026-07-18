import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// Thin wrapper around [HugeIcon] (stroke-rounded) with SYU defaults.
class SyuIcon extends StatelessWidget {
  const SyuIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.5,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );
  }
}

/// Sized for [InputDecoration.prefixIcon] / suffix — matches field text height.
class SyuFieldIcon extends StatelessWidget {
  const SyuFieldIcon(
    this.icon, {
    super.key,
    this.size = 18,
    this.color = SyuColors.mist,
    this.strokeWidth = 1.25,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: SizedBox(
        width: size,
        height: size,
        child: HugeIcon(
          icon: icon,
          size: size,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

/// App-wide [Hugeicons](https://hugeicons.com/) stroke-rounded catalog.
abstract final class SyuIcons {
  static const home = HugeIcons.strokeRoundedHome01;
  static const homeFilled = HugeIcons.strokeRoundedHome02;
  static const news = HugeIcons.strokeRoundedMegaphone01;
  static const newsAlt = HugeIcons.strokeRoundedNews;
  static const calendar = HugeIcons.strokeRoundedCalendar01;
  static const calendarCheck = HugeIcons.strokeRoundedCalendarCheckOut01;
  static const chat = HugeIcons.strokeRoundedMessage01;
  static const chatAlt = HugeIcons.strokeRoundedBubbleChat;
  /// Unseen / unread chat (nav + admin tile).
  static const chatUnread = HugeIcons.strokeRoundedMessageNotification01;
  static const user = HugeIcons.strokeRoundedUser;
  static const userCircle = HugeIcons.strokeRoundedUserCircle;
  static const userCheck = HugeIcons.strokeRoundedUserCheck01;
  static const userEdit = HugeIcons.strokeRoundedUserEdit01;
  static const userAdd = HugeIcons.strokeRoundedUserAdd01;
  static const userGroup = HugeIcons.strokeRoundedUserMultiple02;
  static const people = HugeIcons.strokeRoundedUserGroup;
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const logout = HugeIcons.strokeRoundedLogout01;
  static const edit = HugeIcons.strokeRoundedEdit01;
  static const mail = HugeIcons.strokeRoundedMail01;
  static const mailOpen = HugeIcons.strokeRoundedMailOpen01;
  static const mailUnread = HugeIcons.strokeRoundedMailValidation01;
  static const lock = HugeIcons.strokeRoundedSquareLock01;
  static const lockPassword = HugeIcons.strokeRoundedLockPassword;
  static const resetPassword = HugeIcons.strokeRoundedResetPassword;
  static const view = HugeIcons.strokeRoundedView;
  static const viewOff = HugeIcons.strokeRoundedViewOffSlash;
  static const back = HugeIcons.strokeRoundedArrowLeft01;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const chevronLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const send = HugeIcons.strokeRoundedSent;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const bookmark = HugeIcons.strokeRoundedBookmark02;
  static const bookmarkOutline = HugeIcons.strokeRoundedBookmark01;
  static const chart = HugeIcons.strokeRoundedAnalytics01;
  static const history = HugeIcons.strokeRoundedClock01;
  static const verified = HugeIcons.strokeRoundedCheckmarkBadge01;
  static const notification = HugeIcons.strokeRoundedNotification01;
  static const info = HugeIcons.strokeRoundedInformationCircle;
  static const camera = HugeIcons.strokeRoundedCamera01;
  static const phone = HugeIcons.strokeRoundedCall;
  static const add = HugeIcons.strokeRoundedAdd01;
  static const building = HugeIcons.strokeRoundedBuilding03;

  /// Default accent color for branded icon chips.
  static const Color accent = SyuColors.crimsonSoft;
}
