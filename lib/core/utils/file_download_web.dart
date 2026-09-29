import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Creates a Blob URL and clicks a temporary `<a download>` link.
bool downloadTextFile(String fileName, String content, String mimeType) {
  try {
    final blobClass = globalContext.getProperty<JSFunction>('Blob'.toJS);
    final options = JSObject()..setProperty('type'.toJS, mimeType.toJS);
    final blob = blobClass.callAsConstructor<JSObject>(
      [content.toJS].toJS,
      options,
    );
    final url = globalContext
        .getProperty<JSObject>('URL'.toJS)
        .callMethod<JSString>('createObjectURL'.toJS, blob);
    final document = globalContext.getProperty<JSObject>('document'.toJS);
    final anchor = document.callMethod<JSObject>(
      'createElement'.toJS,
      'a'.toJS,
    )
      ..setProperty('href'.toJS, url)
      ..setProperty('download'.toJS, fileName.toJS);
    document.getProperty<JSObject>('body'.toJS).callMethod<JSAny?>(
      'appendChild'.toJS,
      anchor,
    );
    anchor.callMethod<JSAny?>('click'.toJS);
    anchor.callMethod<JSAny?>('remove'.toJS);
    globalContext
        .getProperty<JSObject>('URL'.toJS)
        .callMethod<JSAny?>('revokeObjectURL'.toJS, url);
    return true;
  } catch (_) {
    return false;
  }
}
