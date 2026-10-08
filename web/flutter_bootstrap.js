{{flutter_js}}
{{flutter_build_config}}

// The app never talks to a third-party host (the test server's CSP forbids it):
// - CanvasKit comes from the build (`flutter build web --no-web-resources-cdn`);
// - Roboto is bundled (pubspec.yaml), so the default font is not downloaded;
// - fallback fonts for characters Roboto lacks (Cyrillic, emoji, CJK...) would
//   default to fonts.gstatic.com; they are pointed at our own origin, where the
//   files do not exist, so such characters show as "tofu" instead of leaking a
//   request.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "assets/fallback-fonts/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
