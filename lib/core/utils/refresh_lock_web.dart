import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const _lockName = 'opt-refresh';

Future<T> withRefreshLock<T>(Future<T> Function() action) {
  final navigator = web.window.navigator as JSObject;
  final locks = navigator.getProperty<JSAny?>('locks'.toJS);
  if (locks == null || locks.isUndefined) return action();

  final result = Completer<T>();
  Future<void> run() async {
    try {
      result.complete(await action());
    } catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    }
  }

  // The lock is held until the promise returned by the callback settles.
  JSAny? granted(JSAny? lock) => run().toJS;
  try {
    (locks as web.LockManager).request(_lockName, granted.toJS);
  } catch (_) {
    // The lock could not be requested; continue without it.
    if (!result.isCompleted) run();
  }
  return result.future;
}
