import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Runtime permissions + external links for SYU (Android / iOS).
abstract final class AppPermissions {
  /// Ask for notification permission once after install / first session.
  /// Safe on web (no-op). Does not re-prompt if permanently denied.
  static Future<PermissionStatus> ensureNotifications() async {
    if (kIsWeb) return PermissionStatus.granted;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) return status;
      if (status.isPermanentlyDenied) return status;
      return Permission.notification.request();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// Returns true if granted; if permanently denied, opens system settings.
  static Future<bool> requestNotificationsOrOpenSettings() async {
    final status = await ensureNotifications();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return notificationsGranted;
  }

  static Future<bool> get notificationsGranted async {
    if (kIsWeb) return true;
    final s = await Permission.notification.status;
    return s.isGranted || s.isLimited;
  }

  /// Open app system settings so the user can enable notifications.
  static Future<bool> openSystemSettings() => openAppSettings();

  /// Open https/http/mailto/tel weblinks in the system browser / handler.
  static Future<bool> openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openHttps(String hostPath) {
    final path = hostPath.startsWith('http') ? hostPath : 'https://$hostPath';
    return openLink(path);
  }
}
