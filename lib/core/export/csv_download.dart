import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart'
    if (dart.library.io) 'csv_download_io.dart' as impl;

/// Saves/shares a text file: browser download on web, share sheet on mobile.
Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  return impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}
