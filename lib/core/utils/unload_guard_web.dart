import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void setHasUnsavedChanges(bool value) {
  final bridge = globalContext.getProperty<JSObject?>('erpShell'.toJS);
  bridge?.setProperty('hasUnsavedChanges'.toJS, value.toJS);
}
