import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shell/login/login_page.dart';
import '../../shell/shell_page.dart';
import '../auth/session_controller.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(
    sessionProvider.select((s) => s.isSignedIn),
    (_, _) => refresh.ping(),
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      signedIn: ref.read(sessionProvider).isSignedIn,
      uri: state.uri,
    ),
    routes: [
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

/// Route guard: signed-out users go to the login page (remembering where
/// they wanted to go); signed-in users are sent away from it.
String? authRedirect({required bool signedIn, required Uri uri}) {
  final onLogin = uri.path == Routes.login;
  if (!signedIn) {
    if (onLogin) return null;
    final from = uri.path == Routes.home ? null : uri.toString();
    return Uri(
      path: Routes.login,
      queryParameters: from == null ? null : {Routes.fromParam: from},
    ).toString();
  }
  if (onLogin) {
    final from = uri.queryParameters[Routes.fromParam];
    return from != null && from.startsWith('/') ? from : Routes.home;
  }
  return null;
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
