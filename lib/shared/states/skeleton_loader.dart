import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';

/// Placeholder blocks shown while content loads. The pulse animation uses a
/// ticker, so it stops in background tabs ([TickerMode]).
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({this.rows = 6, this.lineHeight = 16, super.key});

  final int rows;
  final double lineHeight;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.4,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: context.l10n.loading,
      child: FadeTransition(
        opacity: _pulse,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.rows; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.md),
                  child: FractionallySizedBox(
                    // Vary line lengths so it reads as text.
                    widthFactor: const [1.0, 0.85, 0.7, 0.9, 0.6][i % 5],
                    child: Container(
                      height: widget.lineHeight,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(spacing.xs),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
