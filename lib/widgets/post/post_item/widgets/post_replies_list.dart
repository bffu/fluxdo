import 'package:flutter/material.dart';

import '../../../../models/topic.dart';
import '../../../../services/discourse_cache_manager.dart';
import '../../../../utils/comment_keyword_filter.dart';
import '../../../content/discourse_html_content/discourse_html_content.dart';

class PostRepliesList extends StatelessWidget {
  final List<Post> replies;
  final int replyCount;
  final List<String> blockedKeywords;
  final bool canLoadMore;
  final ValueNotifier<bool> isLoadingRepliesNotifier;
  final ValueNotifier<bool> showRepliesNotifier;
  final VoidCallback onLoadMore;
  final void Function(int postNumber)? onJumpToPost;

  const PostRepliesList({
    super.key,
    required this.replies,
    required this.replyCount,
    this.blockedKeywords = const [],
    required this.canLoadMore,
    required this.isLoadingRepliesNotifier,
    required this.showRepliesNotifier,
    required this.onLoadMore,
    this.onJumpToPost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (replies.isEmpty) return const SizedBox.shrink();

    final visibleReplies = replies
        .where((reply) => !CommentKeywordFilter.isPostBlocked(reply, blockedKeywords))
        .toList();
    final blockedCount = replies.length - visibleReplies.length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  blockedCount > 0
                      ? '$replyCount replies (hidden $blockedCount)'
                      : '$replyCount replies',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (visibleReplies.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'All loaded replies are hidden by keyword filter',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...visibleReplies.map((reply) {
            final avatarUrl = reply.getAvatarUrl(size: 60);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onJumpToPost?.call(reply.postNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? discourseImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  reply.username[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (reply.name != null && reply.name!.isNotEmpty)
                                          ? reply.name!
                                          : reply.username,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '#${reply.postNumber}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              IgnorePointer(
                                child: DiscourseHtmlContent(
                                  html: reply.cooked,
                                  textStyle: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          ValueListenableBuilder<bool>(
            valueListenable: isLoadingRepliesNotifier,
            builder: (context, isLoadingReplies, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canLoadMore)
                    TextButton.icon(
                      onPressed: isLoadingReplies ? null : onLoadMore,
                      icon: isLoadingReplies
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: const Text('Load more replies'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => showRepliesNotifier.value = false,
                    icon: Icon(
                      Icons.expand_less,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      'Collapse replies',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
