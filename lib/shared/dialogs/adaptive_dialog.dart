import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';

/// Shows [content] full screen on phones and as a centered dialog
/// elsewhere. [actions] go to the app bar (phone) or the dialog footer.
Future<T?> showAdaptiveAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context) content,
  List<Widget> Function(BuildContext context)? actions,
  double maxWidth = 640,
}) {
  final compact = Breakpoints.of(context) == WindowSizeClass.compact;
  return showDialog<T>(
    context: context,
    builder: (context) => compact
        ? Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: context.l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
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
                            onPressed: () => Navigator.of(context).pop(),
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
  );
}
