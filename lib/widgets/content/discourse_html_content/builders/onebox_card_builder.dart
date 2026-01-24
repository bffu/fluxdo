import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/discourse_cache_manager.dart';
import '../../../../pages/user_profile_page.dart';

/// 构建链接预览卡片 (onebox)
Widget buildOneboxCard({
  required BuildContext context,
  required ThemeData theme,
  required dynamic element,
}) {
  // 检查是否是用户 onebox
  final articleElement = element.querySelector('article');
  if (articleElement != null && articleElement.classes.contains('user-onebox')) {
    return _buildUserOneboxCard(
      context: context,
      theme: theme,
      element: element,
    );
  }

  // 默认链接预览卡片
  return _buildDefaultOneboxCard(
    context: context,
    theme: theme,
    element: element,
  );
}

/// 构建用户 onebox 卡片
Widget _buildUserOneboxCard({
  required BuildContext context,
  required ThemeData theme,
  required dynamic element,
}) {
  // 提取头像
  final avatarImg = element.querySelector('img');
  final avatarUrl = avatarImg?.attributes['src'] ?? '';

  // 提取用户名
  final h3Element = element.querySelector('h3');
  final usernameLink = h3Element?.querySelector('a');
  final usernameText = usernameLink?.text ?? '';
  // 从 @username 提取 username
  final username = usernameText.startsWith('@') 
      ? usernameText.substring(1) 
      : usernameText;

  // 提取名称
  final nameElement = element.querySelector('.full-name');
  final name = nameElement?.text ?? '';

  // 提取位置
  final locationElement = element.querySelector('.location');
  final location = locationElement?.text?.trim() ?? '';

  // 提取简介
  final bioElement = element.querySelector('p');
  final bio = bioElement?.text ?? '';

  // 提取加入时间
  final joinedElement = element.querySelector('.user-onebox--joined');
  final joined = joinedElement?.text ?? '';

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.colorScheme.outlineVariant,
        width: 1,
      ),
    ),
    child: InkWell(
      onTap: () {
        if (username.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfilePage(username: username),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像
            if (avatarUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image(
                  image: discourseImageProvider(avatarUrl),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    );
                  },
                ),
              ),
            if (avatarUrl.isNotEmpty) const SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户名
                  Text(
                    '@$username',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  // 名称
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                  // 位置
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // 简介
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      bio,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // 加入时间
                  if (joined.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      joined,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 构建默认链接预览卡片
Widget _buildDefaultOneboxCard({
  required BuildContext context,
  required ThemeData theme,
  required dynamic element,
}) {
  // 提取标题
  final h3Element = element.querySelector('h3');
  final titleLink = h3Element?.querySelector('a');
  
  // 提取并移除点击数 span (避免显示在标题中)
  String? clickCount;
  final clickCountSpan = titleLink?.querySelector('.link-click-count');
  if (clickCountSpan != null) {
    clickCount = clickCountSpan.text.trim();
    clickCountSpan.remove();
  }

  final title = titleLink?.text ?? '';
  final url = titleLink?.attributes['href'] ?? '';

  // 提取描述
  final descElement = element.querySelector('p');
  final description = descElement?.text ?? '';

  // 提取图标
  final iconElement = element.querySelector('img.site-icon');
  final iconUrl = iconElement?.attributes['src'] ?? '';

  // 提取来源
  final sourceElement = element.querySelector('.source a');
  // 同样移除来源链接中的点击数 span
  sourceElement?.querySelector('.link-click-count')?.remove();
  final sourceName = sourceElement?.text ?? '';

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: theme.colorScheme.outlineVariant,
        width: 1,
      ),
    ),
    child: InkWell(
      onTap: () async {
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 来源和图标和点击数
            if (sourceName.isNotEmpty || iconUrl.isNotEmpty || clickCount != null)
              Row(
                children: [
                  if (iconUrl.isNotEmpty) ...[
                    Image(
                      image: discourseImageProvider(iconUrl),
                      width: 16,
                      height: 16,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.link, size: 16);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (sourceName.isNotEmpty)
                    Expanded(
                      child: Text(
                        sourceName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (clickCount != null)
                     const Spacer(),
                  
                  if (clickCount != null) ...[
                    if (sourceName.isNotEmpty) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            clickCount,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            if (sourceName.isNotEmpty || iconUrl.isNotEmpty || clickCount != null)
              const SizedBox(height: 8),
            // 标题
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            // 描述
            if (description.isNotEmpty)
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    ),
  );
}
