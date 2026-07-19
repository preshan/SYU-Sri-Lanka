Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  throw UnsupportedError('CSV export is not supported on this platform.');
}
