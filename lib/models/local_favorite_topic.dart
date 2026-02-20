import 'topic.dart';

/// Locally persisted topic snapshot for "Local Favorites".
class LocalFavoriteTopic {
  final int topicId;
  final String folderId;
  final String title;
  final String slug;
  final String categoryId;
  final List<String> tags;
  final int postsCount;
  final int likeCount;
  final String? lastPosterUsername;
  final bool pinned;
  final bool closed;
  final bool unseen;
  final int unread;
  final int? lastReadPostNumber;
  final bool hasAcceptedAnswer;
  final bool canHaveAnswer;
  final int? lastPostedAtMillis;
  final int addedAtMillis;

  const LocalFavoriteTopic({
    required this.topicId,
    required this.folderId,
    required this.title,
    required this.slug,
    required this.categoryId,
    required this.tags,
    required this.postsCount,
    required this.likeCount,
    this.lastPosterUsername,
    required this.pinned,
    required this.closed,
    required this.unseen,
    required this.unread,
    this.lastReadPostNumber,
    required this.hasAcceptedAnswer,
    required this.canHaveAnswer,
    required this.lastPostedAtMillis,
    required this.addedAtMillis,
  });

  DateTime get addedAt => DateTime.fromMillisecondsSinceEpoch(addedAtMillis);

  DateTime? get lastPostedAt => lastPostedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastPostedAtMillis!);

  factory LocalFavoriteTopic.fromTopic(
    Topic topic, {
    required String folderId,
    DateTime? addedAt,
  }) {
    return LocalFavoriteTopic(
      topicId: topic.id,
      folderId: folderId,
      title: topic.title,
      slug: topic.slug,
      categoryId: topic.categoryId,
      tags: topic.tags.map((t) => t.name).toList(),
      postsCount: topic.postsCount,
      likeCount: topic.likeCount,
      lastPosterUsername: topic.lastPosterUsername,
      pinned: topic.pinned,
      closed: topic.closed,
      unseen: topic.unseen,
      unread: topic.unread,
      lastReadPostNumber: topic.lastReadPostNumber,
      hasAcceptedAnswer: topic.hasAcceptedAnswer,
      canHaveAnswer: topic.canHaveAnswer,
      lastPostedAtMillis: topic.lastPostedAt?.millisecondsSinceEpoch,
      addedAtMillis:
          (addedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  factory LocalFavoriteTopic.fromJson(Map<String, dynamic> json) {
    return LocalFavoriteTopic(
      topicId: json['topic_id'] as int? ?? 0,
      folderId: json['folder_id'] as String? ?? 'root',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '0',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((t) => t.toString())
          .toList(),
      postsCount: json['posts_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      lastPosterUsername: json['last_poster_username'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      unseen: json['unseen'] as bool? ?? false,
      unread: json['unread'] as int? ?? 0,
      lastReadPostNumber: json['last_read_post_number'] as int?,
      hasAcceptedAnswer: json['has_accepted_answer'] as bool? ?? false,
      canHaveAnswer: json['can_have_answer'] as bool? ?? false,
      lastPostedAtMillis: json['last_posted_at_millis'] as int?,
      addedAtMillis:
          json['added_at_millis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'folder_id': folderId,
      'title': title,
      'slug': slug,
      'category_id': categoryId,
      'tags': tags,
      'posts_count': postsCount,
      'like_count': likeCount,
      'last_poster_username': lastPosterUsername,
      'pinned': pinned,
      'closed': closed,
      'unseen': unseen,
      'unread': unread,
      'last_read_post_number': lastReadPostNumber,
      'has_accepted_answer': hasAcceptedAnswer,
      'can_have_answer': canHaveAnswer,
      'last_posted_at_millis': lastPostedAtMillis,
      'added_at_millis': addedAtMillis,
    };
  }

  Topic toTopic() {
    return Topic(
      id: topicId,
      title: title,
      slug: slug,
      postsCount: postsCount,
      replyCount: postsCount > 0 ? postsCount - 1 : 0,
      views: 0,
      likeCount: likeCount,
      lastPostedAt: lastPostedAt,
      lastPosterUsername: lastPosterUsername,
      categoryId: categoryId,
      pinned: pinned,
      closed: closed,
      tags: tags.map((name) => Tag(name: name)).toList(),
      unseen: unseen,
      unread: unread,
      lastReadPostNumber: lastReadPostNumber,
      hasAcceptedAnswer: hasAcceptedAnswer,
      canHaveAnswer: canHaveAnswer,
    );
  }
}
