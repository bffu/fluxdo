import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import '../content/discourse_html_content/discourse_html_content.dart';
import '../../services/emoji_handler.dart';

/// Markdown 预览组件
/// 使用官方 markdown 包将 Markdown 转换为 HTML，
/// 再用 DiscourseHtmlContent 渲染，保持与帖子显示样式一致
class MarkdownBody extends StatelessWidget {
  final String data;
  
  const MarkdownBody({super.key, required this.data});
  
  @override
  Widget build(BuildContext context) {
    // 1. 处理 Emoji 替换 (将 :smile: 转为 <img>)
    // 注意：EmojiHandler 需要预先初始化，或者构建时异步获取。
    // 为了简单预览，我们假设它尽力替换，如果在 CreateTopicPage 初始化了最好。
    final processedData = EmojiHandler().replaceEmojis(data);

    // 2. 使用 GitHub Flavored Markdown 扩展集转换为 HTML
    final html = md.markdownToHtml(
      processedData,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    
    // 3. 使用 DiscourseHtmlContent 渲染，与帖子显示保持一致
    return DiscourseHtmlContent(
      html: html,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.5,
      ),
    );
  }
}
