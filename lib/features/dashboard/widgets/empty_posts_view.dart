import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';

class EmptyPostsView extends StatelessWidget {
  /// Repo-relative folder the app syncs posts from (shown in the copy)
  final String postsFolder;

  const EmptyPostsView({super.key, this.postsFolder = '_posts'});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: scheme.outline.withAlpha(40),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.primary.withAlpha(30),
                ),
              ),
              child: Icon(
                Icons.article_outlined,
                size: 56,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              context.l10n.noPostsYet,
              style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.emptyPostsBody(postsFolder),
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outline.withAlpha(80),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.tapPlusToWrite,
                    style: context.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
