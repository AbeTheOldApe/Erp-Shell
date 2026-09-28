/// Route paths.
abstract final class Routes {
  static const home = '/';
  static const login = '/login';
  static const modulePattern = '/m/:moduleKey';
  static const fromParam = 'from';

  static String module(String moduleKey, [Map<String, String>? query]) => Uri(
    path: '/m/$moduleKey',
    queryParameters: query == null || query.isEmpty ? null : query,
  ).toString();

  /// Module key of a `/m/<key>` location, otherwise `null`.
  static String? moduleKeyOf(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'm' && segments[1].isNotEmpty) {
      return segments[1];
    }
    return null;
  }
}
