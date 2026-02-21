import 'topic.dart';

/// Locally persisted topic snapshot for "Local Favorites".
class LocalFavoriteTopic {
  static const unavailableReasonDeleted = 'deleted';
  static const unavailableReasonForbidden = 'forbidden';
  static const unavailableReasonNetwork = 'network';

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
  final bool archivedLocally;
  final int? archiveUpdatedAtMillis;
  final bool sourceUnavailable;
  final String? sourceUnavailableReason;

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
    this.archivedLocally = false,
    this.archiveUpdatedAtMillis,
    this.sourceUnavailable = false,
    this.sourceUnavailableReason,
  });

  DateTime get addedAt => DateTime.fromMillisecondsSinceEpoch(addedAtMillis);

  DateTime? get lastPostedAt => lastPostedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastPostedAtMillis!);

  DateTime? get archiveUpdatedAt => archiveUpdatedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(archiveUpdatedAtMillis!);

  String get displayTitle {
    if (!sourceUnavailable) return title;
    if (sourceUnavailableReason == unavailableReasonDeleted) {
      return '[已删除] $title';
    }
    if (sourceUnavailableReason == unavailableReasonForbidden) {
      return '[无权限] $title';
    }
    return '[离线归档] $title';
  }

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
      archivedLocally: false,
      archiveUpdatedAtMillis: null,
      sourceUnavailable: false,
      sourceUnavailableReason: null,
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
      archivedLocally: json['archived_locally'] as bool? ?? false,
      archiveUpdatedAtMillis: json['archive_updated_at_millis'] as int?,
      sourceUnavailable: json['source_unavailable'] as bool? ?? false,
      sourceUnavailableReason: json['source_unavailable_reason'] as String?,
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
      'archived_locally': archivedLocally,
      'archive_updated_at_millis': archiveUpdatedAtMillis,
      'source_unavailable': sourceUnavailable,
      'source_unavailable_reason': sourceUnavailableReason,
    };
  }

  LocalFavoriteTopic copyWith({
    int? topicId,
    String? folderId,
    String? title,
    String? slug,
    String? categoryId,
    List<String>? tags,
    int? postsCount,
    int? likeCount,
    String? lastPosterUsername,
    bool? pinned,
    bool? closed,
    bool? unseen,
    int? unread,
    int? lastReadPostNumber,
    bool? hasAcceptedAnswer,
    bool? canHaveAnswer,
    int? lastPostedAtMillis,
    int? addedAtMillis,
    bool? archivedLocally,
    int? archiveUpdatedAtMillis,
    bool? sourceUnavailable,
    String? sourceUnavailableReason,
    bool clearSourceUnavailableReason = false,
  }) {
    return LocalFavoriteTopic(
      topicId: topicId ?? this.topicId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      postsCount: postsCount ?? this.postsCount,
      likeCount: likeCount ?? this.likeCount,
      lastPosterUsername: lastPosterUsername ?? this.lastPosterUsername,
      pinned: pinned ?? this.pinned,
      closed: closed ?? this.closed,
      unseen: unseen ?? this.unseen,
      unread: unread ?? this.unread,
      lastReadPostNumber: lastReadPostNumber ?? this.lastReadPostNumber,
      hasAcceptedAnswer: hasAcceptedAnswer ?? this.hasAcceptedAnswer,
      canHaveAnswer: canHaveAnswer ?? this.canHaveAnswer,
      lastPostedAtMillis: lastPostedAtMillis ?? this.lastPostedAtMillis,
      addedAtMillis: addedAtMillis ?? this.addedAtMillis,
      archivedLocally: archivedLocally ?? this.archivedLocally,
      archiveUpdatedAtMillis: archiveUpdatedAtMillis ?? this.archiveUpdatedAtMillis,
      sourceUnavailable: sourceUnavailable ?? this.sourceUnavailable,
      sourceUnavailableReason: clearSourceUnavailableReason
          ? null
          : (sourceUnavailableReason ?? this.sourceUnavailableReason),
    );
  }

  Topic toTopic() {
    return Topic(
      id: topicId,
      title: displayTitle,
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
