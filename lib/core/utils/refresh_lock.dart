import 'refresh_lock_stub.dart'
    if (dart.library.js_interop) 'refresh_lock_web.dart'
    as platform;

/// Runs [action] while holding the browser-wide `opt-refresh` lock
/// (Web Locks API), so that only one browser tab refreshes the session at a
/// time. Runs without a lock where the API is not available.
Future<T> withRefreshLock<T>(Future<T> Function() action) =>
    platform.withRefreshLock(action);
