import 'package:intl/intl.dart';

/// CSV helpers + SYU export filenames.
abstract final class SyuCsv {
  static String cell(Object? value) {
    final raw = (value ?? '').toString();
    if (raw.contains(',') ||
        raw.contains('"') ||
        raw.contains('\n') ||
        raw.contains('\r')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  static String row(Iterable<Object?> values) =>
      values.map(cell).join(',');

  static String table({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buf = StringBuffer()
      ..writeln(row(headers))
      ..writeAll(rows.map(row), '\n');
    if (rows.isNotEmpty) buf.writeln();
    return buf.toString();
  }

  /// Comma-separated language skills, e.g. `Sinhala, Tamil, English`.
  static String languagesJoined(Map<String, dynamic> profile) {
    final langs = <String>[
      if (profile['speaks_sinhala'] == true) 'Sinhala',
      if (profile['speaks_tamil'] == true) 'Tamil',
      if (profile['speaks_english'] == true) 'English',
    ];
    return langs.join(', ');
  }

  /// Comma-separated qualification names, highest-first by level_order.
  static String qualificationsJoined(Map<String, dynamic> profile) {
    final raw = profile['member_qualifications'];
    if (raw is! List || raw.isEmpty) return '';
    final items = <({String name, int order})>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final q = row['qualifications'];
      if (q is! Map) continue;
      final code = (q['code'] as String?)?.toLowerCase();
      final order = (q['level_order'] as num?)?.toInt() ?? 0;
      final name = switch (code) {
        'ol' => 'O/L',
        'al' => 'A/L',
        _ => (q['name_en'] as String?)?.trim().isNotEmpty == true
            ? q['name_en'] as String
            : (code ?? ''),
      };
      if (name.isEmpty) continue;
      items.add((name: name, order: code == 'other' ? -1 : order));
    }
    items.sort((a, b) => b.order.compareTo(a.order));
    return items.map((e) => e.name).join(', ');
  }

  /// Safe single path segment (letters, digits, underscore, hyphen).
  static String slug(String input, {int max = 48}) {
    var s = input.trim().replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[^\w\-]+'), '');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.isEmpty) s = 'data';
    if (s.length > max) s = s.substring(0, max);
    return s;
  }

  static String dateStamp([DateTime? when]) =>
      DateFormat('yyyy-MM-dd').format(when ?? DateTime.now());

  /// `SYU_users[_District][_DS][_GN]_yyyy-MM-dd.csv`
  static String membersFilename({
    String? districtName,
    String? dsName,
    String? gnName,
    DateTime? when,
  }) {
    final parts = <String>['SYU_users'];
    if (districtName != null && districtName.isNotEmpty) {
      parts.add(slug(districtName));
    }
    if (dsName != null && dsName.isNotEmpty) {
      parts.add(slug(dsName));
    }
    if (gnName != null && gnName.isNotEmpty) {
      parts.add(slug(gnName));
    }
    parts.add(dateStamp(when));
    return '${parts.join('_')}.csv';
  }

  /// `SYU_{event_name}_data.csv`
  static String eventFilename(String eventTitle) =>
      'SYU_${slug(eventTitle)}_data.csv';
}
