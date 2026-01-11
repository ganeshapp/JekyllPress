import 'package:flutter/material.dart';
import '../../../core/models/blog_post.dart';

class PostCard extends StatelessWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF162A1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: post.isLocalDraft
                    ? const Color(0xFFE8A87C).withAlpha(60)
                    : const Color(0xFF2D4A3E).withAlpha(80),
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
                          if (post.isLocalDraft)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8A87C).withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 14,
                                    color: Color(0xFFE8A87C),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Draft',
                                    style: TextStyle(
                                      color: Color(0xFFE8A87C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            post.title,
                            style: const TextStyle(
                              color: Color(0xFFF5F5F0),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: const Color(0xFFA8B5A0).withAlpha(150),
                      size: 24,
                    ),
                  ],
                ),
                if (post.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.excerpt,
                    style: const TextStyle(
                      color: Color(0xFFA8B5A0),
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
                      Icons.calendar_today_rounded,
                      _formatDate(post.date),
                    ),
                    const SizedBox(width: 12),
                    if (post.fileName != null)
                      Expanded(
                        child: _buildMetaChip(
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

  Widget _buildMetaChip(IconData icon, String label, {bool isFlexible = false}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: const Color(0xFFA8B5A0).withAlpha(180),
        ),
        const SizedBox(width: 5),
        isFlexible
            ? Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFFA8B5A0).withAlpha(180),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: const Color(0xFFA8B5A0).withAlpha(180),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A3E).withAlpha(50),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
