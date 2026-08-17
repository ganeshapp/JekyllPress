import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/blog_post.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';

class PostCard extends StatelessWidget {
  final BlogPost post;
  final VoidCallback onTap;

  /// True when this card shows a Jekyll draft living on GitHub (under
  /// the configured drafts dir)
  final bool isRemoteDraft;

  /// Overflow-menu actions; the menu only appears when at least one is
  /// provided
  final VoidCallback? onViewPost;
  final VoidCallback? onPromote;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.isRemoteDraft = false,
    this.onViewPost,
    this.onPromote,
    this.onDelete,
  });

  bool get _hasMenu =>
      onViewPost != null || onPromote != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRemoteDraft
                    ? scheme.primary.withAlpha(60)
                    : scheme.outline.withAlpha(80),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRemoteDraft) _buildDraftBadge(context),
                          Text(
                            post.title,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_hasMenu)
                      _buildMenu(context)
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant.withAlpha(150),
                        size: 24,
                      ),
                  ],
                ),
                if (post.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.excerpt,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildMetaChip(
                      context,
                      Icons.calendar_today_rounded,
                      _formatDate(context, post.date),
                    ),
                    const SizedBox(width: 12),
                    if (post.fileName != null)
                      Expanded(
                        child: _buildMetaChip(
                          context,
                          Icons.insert_drive_file_outlined,
                          post.fileName!,
                          isFlexible: true,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftBadge(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      label: context.l10n.draftOnGitHubSemantics,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: scheme.primary.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_queue_rounded,
              size: 14,
              color: scheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.draftBadge,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: context.l10n.postActionsTooltip,
        icon: Icon(
          Icons.more_vert_rounded,
          color: scheme.onSurfaceVariant.withAlpha(180),
          size: 20,
        ),
        onSelected: (value) {
          switch (value) {
            case 'view':
              onViewPost?.call();
            case 'promote':
              onPromote?.call();
            case 'delete':
              onDelete?.call();
          }
        },
        itemBuilder: (context) => [
          if (onViewPost != null)
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(context.l10n.viewPostAction),
                ],
              ),
            ),
          if (onPromote != null)
            PopupMenuItem(
              value: 'promote',
              child: Row(
                children: [
                  const Icon(Icons.publish_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(context.l10n.promoteToPostAction),
                ],
              ),
            ),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.deleteFromGitHubAction,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context,
    IconData icon,
    String label, {
    bool isFlexible = false,
  }) {
    final scheme = context.colorScheme;
    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant.withAlpha(180),
      fontSize: 11,
      fontFamily: 'monospace',
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: scheme.onSurfaceVariant.withAlpha(180),
        ),
        const SizedBox(width: 5),
        isFlexible
            ? Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(label, style: labelStyle),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.outline.withAlpha(50),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  String _formatDate(BuildContext context, String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat.yMMMd(context.l10n.localeName).format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
