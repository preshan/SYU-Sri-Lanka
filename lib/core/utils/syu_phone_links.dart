/// Phone helpers for call / WhatsApp links.
abstract final class SyuPhoneLinks {
  /// Digits only, with leading country code when possible (no +).
  static String? digitsForWa(String? raw) {
    if (raw == null) return null;
    var d = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (d.isEmpty) return null;
    if (d.startsWith('+')) d = d.substring(1);
    if (d.startsWith('0') && d.length >= 9) {
      d = '94${d.substring(1)}';
    }
    if (d.length < 9) return null;
    return d;
  }

  static String? whatsappUrl(String? raw) {
    final d = digitsForWa(raw);
    if (d == null) return null;
    return 'https://wa.me/$d';
  }

  static String? telUrl(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length < 7) return null;
    return 'tel:$cleaned';
  }

  static String? mailtoUrl(String? raw) {
    final email = raw?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) return null;
    return 'mailto:$email';
  }
}
