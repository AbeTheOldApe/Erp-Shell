import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Permanent information band at the top of a form.
class CariInfoBand extends StatelessWidget {
  const CariInfoBand({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: scheme.onSecondaryContainer),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
