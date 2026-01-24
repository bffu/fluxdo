import 'package:flutter/material.dart';
import '../../../../services/discourse_cache_manager.dart';

/// 构建回复引用卡片
Widget buildQuoteCard({
  required BuildContext context,
  required ThemeData theme,
  required dynamic element,
  required Widget Function(String html, TextStyle? textStyle) htmlBuilder,
}) {
  final username = element.attributes['data-username'] ?? '引用';
  final imgElement = element.querySelector('img.avatar');
  final avatarUrl = imgElement?.attributes['src'] ?? '';
  final blockquoteElement = element.querySelector('blockquote');
  final quoteContent = blockquoteElement?.innerHtml ?? '';

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: Border(
        left: BorderSide(
          color: theme.colorScheme.outline,
          width: 4,
        ),
      ),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(4),
        bottomRight: Radius.circular(4),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 引用头部：头像 + 用户名
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              if (avatarUrl.isNotEmpty) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundImage: discourseImageProvider(avatarUrl),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$username:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // 引用内容
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: htmlBuilder(
            quoteContent,
            theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
