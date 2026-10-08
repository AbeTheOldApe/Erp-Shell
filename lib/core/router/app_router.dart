import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shell/login/login_page.dart';
import '../../shell/shell_page.dart';
import '../../shell/startup_page.dart';
import '../auth/session_controller.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider.select((s) => s.status), (previous, next) {
    // Expired <-> active keeps the user in place; only sign-in, sign-out and
    // the end of the startup refresh change where the router sends them.
    final wasIn =
        previous == SessionStatus.active || previous == SessionStatus.expired;
    final isIn = next == SessionStatus.active || next == SessionStatus.expired;
    if (wasIn != isIn || previous == SessionStatus.restoring) refresh.ping();
  });

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      return authRedirect(
        signedIn: session.isSignedIn,
        restoring: session.isRestoring,
        uri: state.uri,
      );
    },
    routes: [
      GoRoute(
        path: Routes.loading,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: StartupPage()),
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => NoTransitionPage(
          child: LoginPage(from: state.uri.queryParameters[Routes.fromParam]),
        ),
      ),
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: ShellPage(location: state.uri, child: child),
        ),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SizedBox.shrink()),
          ),
          GoRoute(
            path: Routes.modulePattern,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SizedBox.shrink()),
          ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) =>
        const NoTransitionPage(child: _UnknownRouteRedirect()),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Route guard: while the startup refresh runs everything waits on the
/// loading page; signed-out users then go to the login page (remembering
/// where they wanted to go); signed-in users are sent away from it.
String? authRedirect({
  required bool signedIn,
  required Uri uri,
  bool restoring = false,
}) {
  final onLogin = uri.path == Routes.login;
  final onLoading = uri.path == Routes.loading;
  if (restoring) {
    if (onLoading) return null;
    return _withFrom(Routes.loading, uri);
  }
  if (onLoading) {
    // go_router does not redirect a second time, so the final destination
    // is chosen here: the wanted page, or the login page that remembers it.
    final from = uri.queryParameters[Routes.fromParam];
    final wanted = from != null && from.startsWith('/') ? from : null;
    if (signedIn) return wanted ?? Routes.home;
    return Uri(
      path: Routes.login,
      queryParameters: wanted == null ? null : {Routes.fromParam: wanted},
    ).toString();
  }
  if (!signedIn) {
    if (onLogin) return null;
    return _withFrom(Routes.login, uri);
  }
  if (onLogin) {
    final from = uri.queryParameters[Routes.fromParam];
    return from != null && from.startsWith('/') ? from : Routes.home;
  }
  return null;
}

String _withFrom(String path, Uri uri) {
  final from = uri.path == Routes.home ? null : uri.toString();
  return Uri(
    path: path,
    queryParameters: from == null ? null : {Routes.fromParam: from},
  ).toString();
}

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Unknown paths fall back to the shell's home.
class _UnknownRouteRedirect extends StatefulWidget {
  const _UnknownRouteRedirect();

  @override
  State<_UnknownRouteRedirect> createState() => _UnknownRouteRedirectState();
}

class _UnknownRouteRedirectState extends State<_UnknownRouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.home);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
