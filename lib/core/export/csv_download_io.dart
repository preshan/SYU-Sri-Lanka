import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Write CSV to a temp file and open the system share sheet (Save / Drive / Files).
/// No storage permission required on modern Android/iOS.
Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$safeName');
  await file.writeAsString(content, flush: true);

  final result = await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType: mimeType.split(';').first.trim(),
          name: safeName,
        ),
      ],
      subject: safeName,
      text: safeName,
    ),
  );

  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('Sharing is not available on this device.');
  }
}
