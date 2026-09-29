import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart'
    as platform;

/// Offers [content] to the user as a file named [fileName] (browser
/// download on the web). Returns false where downloads are not supported.
bool downloadTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv;charset=utf-8',
}) => platform.downloadTextFile(fileName, content, mimeType);
