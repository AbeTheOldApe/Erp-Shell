// Page scripts of index.html. They live in a file (not inline) so that a
// Content-Security-Policy with `script-src 'self'` can be enforced.

// The app manages its own context menus. Ctrl + right click still opens the
// browser menu (useful for debugging).
document.addEventListener('contextmenu', function (e) {
  if (!e.ctrlKey) e.preventDefault();
});

// Bridge for unsaved changes. The Dart side sets
// `window.erpShell.hasUnsavedChanges` when any tab is dirty.
window.erpShell = { hasUnsavedChanges: false };
window.addEventListener('beforeunload', function (e) {
  if (window.erpShell && window.erpShell.hasUnsavedChanges) {
    e.preventDefault();
    e.returnValue = '';
  }
});

// Remove the loading indicator once Flutter has drawn its first frame.
window.addEventListener('flutter-first-frame', function () {
  var loader = document.getElementById('app-loader');
  if (!loader) return;
  loader.classList.add('hidden');
  setTimeout(function () { loader.remove(); }, 250);
});
