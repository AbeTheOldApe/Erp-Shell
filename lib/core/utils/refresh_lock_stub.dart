Future<T> withRefreshLock<T>(Future<T> Function() action) => action();
