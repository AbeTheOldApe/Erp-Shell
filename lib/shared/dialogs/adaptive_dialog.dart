import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';

/// Shows [content] full screen on phones and as a centered dialog
/// elsewhere. [actions] go to the app bar (phone) or the dialog footer.
///
/// [onWillClose] is asked when the user dismisses the dialog (cancel, close
/// button, barrier, back); it closes only if it returns true. A pop with a
/// result, e.g. after saving, is not asked.
Future<T?> showAdaptiveAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context) content,
  List<Widget> Function(BuildContext context)? actions,
  double maxWidth = 640,
  Future<bool> Function()? onWillClose,
}) {
  final compact = Breakpoints.of(context) == WindowSizeClass.compact;
  Widget guarded(BuildContext context, Widget child) {
    if (onWillClose == null) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await onWillClose()) navigator.pop();
      },
      child: child,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) => guarded(
      context,
      compact
          ? Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  title: Text(title),
                  actions: [
                    ...?actions?.call(context),
                    SizedBox(width: context.spacing.sm),
                  ],
                ),
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(context.spacing.md),
                    child: content(context),
                  ),
                ),
              ),
            )
          // Not AlertDialog: it sizes content with IntrinsicWidth, which
          // LayoutBuilder-based content (e.g. ResponsiveForm) cannot support.
          : Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: context.spacing.md),
                      Flexible(
                        child: SingleChildScrollView(
                          // Room for the focus/label decoration of fields.
                          padding: EdgeInsets.only(top: context.spacing.sm),
                          child: content(context),
                        ),
                      ),
                      if (actions != null) ...[
                        SizedBox(height: context.spacing.lg),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: context.spacing.sm,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text(context.l10n.cancel),
                            ),
                            ...actions(context),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
