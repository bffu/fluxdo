import 'package:flutter/material.dart';
import '../callout/callout_builder.dart';

/// 构建普通引用块 (支持 Obsidian Callout)
Widget buildBlockquote({
  required BuildContext context,
  required ThemeData theme,
  required dynamic element,
  required Widget Function(String html, TextStyle? textStyle) htmlBuilder,
}) {
  final innerHtml = element.innerHtml as String;

  // 尝试解析 Obsidian Callout: [!type], [!type]+ (展开), [!type]- (折叠)
  // 从 HTML 中提取第一行（到 <br> 或换行符为止）
  final htmlWithLineBreaks = innerHtml.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  final textContent = htmlWithLineBreaks.replaceAll(RegExp(r'<[^>]*>'), '');
  final firstLine = textContent.trim().split(RegExp(r'[\n\r]')).first.trim();

  // 匹配 [!type], [!type]+, [!type]- 以及可选的标题
  final calloutMatch = RegExp(r'^\[!(\w+)\]([+-])?\s*(.*)').firstMatch(firstLine);

  if (calloutMatch != null) {
    final type = calloutMatch.group(1)!.toLowerCase();
    final foldMarker = calloutMatch.group(2); // + 或 - 或 null
    final title = calloutMatch.group(3)?.trim();

    // 确定折叠状态: null=不可折叠, true=默认展开, false=默认折叠
    bool? foldable;
    if (foldMarker == '+') {
      foldable = true; // 可折叠，默认展开
    } else if (foldMarker == '-') {
      foldable = false; // 可折叠，默认折叠
    }

    return buildCalloutBlock(
      context: context,
      theme: theme,
      innerHtml: innerHtml,
      type: type,
      title: title,
      foldable: foldable,
      htmlBuilder: htmlBuilder,
    );
  }

  // 普通引用块 - 使用灰色
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
    child: htmlBuilder(
      innerHtml,
      theme.textTheme.bodyMedium?.copyWith(
        height: 1.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
