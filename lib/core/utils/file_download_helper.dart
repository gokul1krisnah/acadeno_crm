import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as impl;

/// Universal file download helper for CSV and report exports.
class FileDownloadHelper {
  /// Downloads a CSV file with [fileName] and [content].
  /// On Web: triggers browser download prompt.
  /// On Mobile/Desktop: saves to disk and/or copies to clipboard.
  static Future<bool> downloadCsv({
    required String fileName,
    required String content,
  }) =>
      impl.downloadCsv(fileName: fileName, content: content);
}

