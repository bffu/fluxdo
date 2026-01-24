import 'dart:ui';
import 'package:flutter/material.dart';
import '../../lazy_load_scope.dart';

/// Spoiler 缓存 key 前缀
const _spoilerPrefix = 'spoiler:';

/// 检查 spoiler 是否已显示（基于作用域）
bool isSpoilerRevealed(BuildContext context, String innerHtml) {
  return LazyLoadScope.isLoaded(context, '$_spoilerPrefix${innerHtml.hashCode}');
}

/// 标记 spoiler 已显示
void _markSpoilerRevealed(BuildContext context, String innerHtml) {
  LazyLoadScope.markLoaded(context, '$_spoilerPrefix${innerHtml.hashCode}');
}

/// Spoiler 隐藏内容组件（仅用于未显示状态）
class SpoilerContent extends StatelessWidget {
  final String innerHtml;
  final Widget Function(String html, TextStyle? textStyle) htmlBuilder;
  final TextStyle? textStyle;
  final VoidCallback onReveal;

  const SpoilerContent({
    super.key,
    required this.innerHtml,
    required this.htmlBuilder,
    required this.onReveal,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = htmlBuilder(innerHtml, textStyle);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerUp: (_) => onReveal(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(2),
        ),
        child: ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5, tileMode: TileMode.decal),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 构建 Spoiler 隐藏内容（返回 null 表示已显示，使用默认渲染）
Widget? buildSpoiler({
  required BuildContext context,
  required ThemeData theme,
  required dynamic element,
  required Widget Function(String html, TextStyle? textStyle) htmlBuilder,
  required VoidCallback onStateChanged,
  TextStyle? textStyle,
}) {
  final innerHtml = element.innerHtml as String;

  // 已显示，返回 null 让默认渲染器处理（可选中）
  if (isSpoilerRevealed(context, innerHtml)) {
    return null;
  }

  // 未显示，返回模糊内容
  return SpoilerContent(
    innerHtml: innerHtml,
    htmlBuilder: htmlBuilder,
    textStyle: textStyle,
    onReveal: () {
      _markSpoilerRevealed(context, innerHtml);
      onStateChanged();
    },
  );
}
