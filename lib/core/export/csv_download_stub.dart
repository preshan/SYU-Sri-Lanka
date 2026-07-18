void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  throw UnsupportedError('CSV download is only available on web.');
}
