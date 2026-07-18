import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart' as impl;

/// Triggers a file download (web) or no-op stub elsewhere.
void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}
