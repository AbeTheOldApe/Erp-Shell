import 'unload_guard_stub.dart'
    if (dart.library.js_interop) 'unload_guard_web.dart'
    as platform;

/// Tells `web/index.html` whether a `beforeunload` warning is needed.
void setHasUnsavedChanges(bool value) => platform.setHasUnsavedChanges(value);
