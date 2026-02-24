import '../models/topic.dart';

/// 评论关键词匹配工具
class CommentKeywordFilter {
  static final RegExp _splitPattern = RegExp(r'[\n,，;；|]+');
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>', multiLine: true);
  static final RegExp _multiSpacePattern = RegExp(r'\s+');

  /// 归一化关键词列表：去空、去重、转小写
  static List<String> normalizeKeywords(List<String> keywords) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final keyword in keywords) {
      final value = keyword.trim().toLowerCase();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      normalized.add(value);
    }

    return normalized;
  }

  /// 从用户输入文本解析关键词列表（支持换行/逗号/分号分隔）
  static List<String> parseKeywords(String rawInput) {
    return normalizeKeywords(rawInput.split(_splitPattern));
  }

  /// 帖子是否命中关键词
  static bool isPostBlocked(Post post, List<String> keywords) {
    if (keywords.isEmpty) return false;
    return firstMatchedKeyword(post, keywords) != null;
  }

  /// 返回第一个命中的关键词，未命中则为 null
  static String? firstMatchedKeyword(Post post, List<String> keywords) {
    final normalizedKeywords = normalizeKeywords(keywords);
    if (normalizedKeywords.isEmpty) return null;

    final plainText = post.cooked
        .replaceAll(_htmlTagPattern, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(_multiSpacePattern, ' ')
        .trim();

    final searchable = [
      post.username,
      if (post.name != null) post.name!,
      plainText,
    ].join('\n').toLowerCase();

    for (final keyword in normalizedKeywords) {
      if (searchable.contains(keyword)) {
        return keyword;
      }
    }
    return null;
  }
}
