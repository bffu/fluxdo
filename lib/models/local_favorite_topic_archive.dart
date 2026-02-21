import 'topic.dart';

/// Full offline archive for a local-favorite topic.
class LocalFavoriteTopicArchive {
  final int topicId;
  final String title;
  final String slug;
  final int categoryId;
  final int postsCount;
  final bool closed;
  final bool archived;
  final int views;
  final int likeCount;
  final int? createdAtMillis;
  final int? lastReadPostNumber;
  final bool hasSummary;
  final bool hasAcceptedAnswer;
  final int? acceptedAnswerPostNumber;
  final String archetype;
  final int notificationLevel;
  final List<String> tags;
  final List<int> stream;
  final List<LocalFavoriteArchivedPost> posts;
  final int archivedAtMillis;
  final int lastSyncedAtMillis;

  const LocalFavoriteTopicArchive({
    required this.topicId,
    required this.title,
    required this.slug,
    required this.categoryId,
    required this.postsCount,
    required this.closed,
    required this.archived,
    required this.views,
    required this.likeCount,
    required this.createdAtMillis,
    required this.lastReadPostNumber,
    required this.hasSummary,
    required this.hasAcceptedAnswer,
    required this.acceptedAnswerPostNumber,
    required this.archetype,
    required this.notificationLevel,
    required this.tags,
    required this.stream,
    required this.posts,
    required this.archivedAtMillis,
    required this.lastSyncedAtMillis,
  });

  factory LocalFavoriteTopicArchive.fromTopicDetail(
    TopicDetail detail, {
    DateTime? archivedAt,
    DateTime? lastSyncedAt,
  }) {
    final now = DateTime.now();
    return LocalFavoriteTopicArchive(
      topicId: detail.id,
      title: detail.title,
      slug: detail.slug,
      categoryId: detail.categoryId,
      postsCount: detail.postsCount,
      closed: detail.closed,
      archived: detail.archived,
      views: detail.views,
      likeCount: detail.likeCount,
      createdAtMillis: detail.createdAt?.millisecondsSinceEpoch,
      lastReadPostNumber: detail.lastReadPostNumber,
      hasSummary: detail.hasSummary,
      hasAcceptedAnswer: detail.hasAcceptedAnswer,
      acceptedAnswerPostNumber: detail.acceptedAnswerPostNumber,
      archetype: detail.archetype,
      notificationLevel: detail.notificationLevel.value,
      tags: detail.tags?.map((e) => e.name).toList() ?? const [],
      stream: List<int>.from(detail.postStream.stream),
      posts: detail.postStream.posts
          .map(LocalFavoriteArchivedPost.fromPost)
          .toList(),
      archivedAtMillis: (archivedAt ?? now).millisecondsSinceEpoch,
      lastSyncedAtMillis: (lastSyncedAt ?? now).millisecondsSinceEpoch,
    );
  }

  factory LocalFavoriteTopicArchive.fromJson(Map<String, dynamic> json) {
    return LocalFavoriteTopicArchive(
      topicId: json['topic_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      categoryId: json['category_id'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      closed: json['closed'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      views: json['views'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      createdAtMillis: json['created_at_millis'] as int?,
      lastReadPostNumber: json['last_read_post_number'] as int?,
      hasSummary: json['has_summary'] as bool? ?? false,
      hasAcceptedAnswer: json['has_accepted_answer'] as bool? ?? false,
      acceptedAnswerPostNumber: json['accepted_answer_post_number'] as int?,
      archetype: json['archetype'] as String? ?? 'regular',
      notificationLevel: json['notification_level'] as int? ?? 1,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      stream: (json['stream'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList(),
      posts: (json['posts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => LocalFavoriteArchivedPost.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      archivedAtMillis:
          json['archived_at_millis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      lastSyncedAtMillis:
          json['last_synced_at_millis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'title': title,
      'slug': slug,
      'category_id': categoryId,
      'posts_count': postsCount,
      'closed': closed,
      'archived': archived,
      'views': views,
      'like_count': likeCount,
      'created_at_millis': createdAtMillis,
      'last_read_post_number': lastReadPostNumber,
      'has_summary': hasSummary,
      'has_accepted_answer': hasAcceptedAnswer,
      'accepted_answer_post_number': acceptedAnswerPostNumber,
      'archetype': archetype,
      'notification_level': notificationLevel,
      'tags': tags,
      'stream': stream,
      'posts': posts.map((e) => e.toJson()).toList(),
      'archived_at_millis': archivedAtMillis,
      'last_synced_at_millis': lastSyncedAtMillis,
    };
  }

  TopicDetail toTopicDetail() {
    final postMap = <int, Post>{
      for (final post in posts) post.id: post.toPost(),
    };
    final orderedPosts = <Post>[];
    for (final postId in stream) {
      final post = postMap[postId];
      if (post != null) {
        orderedPosts.add(post);
      }
    }
    if (orderedPosts.isEmpty) {
      orderedPosts
        ..addAll(postMap.values)
        ..sort((a, b) => a.postNumber.compareTo(b.postNumber));
    }

    return TopicDetail(
      id: topicId,
      title: title,
      slug: slug,
      postsCount: postsCount,
      postStream: PostStream(
        posts: orderedPosts,
        stream: stream.isNotEmpty
            ? List<int>.from(stream)
            : orderedPosts.map((e) => e.id).toList(),
      ),
      categoryId: categoryId,
      closed: closed,
      archived: archived,
      tags: tags.map((e) => Tag(name: e)).toList(),
      views: views,
      likeCount: likeCount,
      createdAt: createdAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMillis!),
      lastReadPostNumber: lastReadPostNumber,
      hasSummary: hasSummary,
      notificationLevel: TopicNotificationLevel.fromValue(notificationLevel),
      archetype: archetype,
      hasAcceptedAnswer: hasAcceptedAnswer,
      acceptedAnswerPostNumber: acceptedAnswerPostNumber,
    );
  }
}

class LocalFavoriteArchivedPost {
  final int id;
  final String? name;
  final String username;
  final String avatarTemplate;
  final String? animatedAvatar;
  final String cooked;
  final int postNumber;
  final int postType;
  final int updatedAtMillis;
  final int createdAtMillis;
  final int likeCount;
  final int replyCount;
  final int replyToPostNumber;
  final bool scoreHidden;
  final bool bookmarked;
  final int? bookmarkId;
  final bool read;
  final bool acceptedAnswer;
  final int? deletedAtMillis;
  final bool userDeleted;

  const LocalFavoriteArchivedPost({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarTemplate,
    required this.animatedAvatar,
    required this.cooked,
    required this.postNumber,
    required this.postType,
    required this.updatedAtMillis,
    required this.createdAtMillis,
    required this.likeCount,
    required this.replyCount,
    required this.replyToPostNumber,
    required this.scoreHidden,
    required this.bookmarked,
    required this.bookmarkId,
    required this.read,
    required this.acceptedAnswer,
    required this.deletedAtMillis,
    required this.userDeleted,
  });

  factory LocalFavoriteArchivedPost.fromPost(Post post) {
    return LocalFavoriteArchivedPost(
      id: post.id,
      name: post.name,
      username: post.username,
      avatarTemplate: post.avatarTemplate,
      animatedAvatar: post.animatedAvatar,
      cooked: post.cooked,
      postNumber: post.postNumber,
      postType: post.postType,
      updatedAtMillis: post.updatedAt.millisecondsSinceEpoch,
      createdAtMillis: post.createdAt.millisecondsSinceEpoch,
      likeCount: post.likeCount,
      replyCount: post.replyCount,
      replyToPostNumber: post.replyToPostNumber,
      scoreHidden: post.scoreHidden,
      bookmarked: post.bookmarked,
      bookmarkId: post.bookmarkId,
      read: post.read,
      acceptedAnswer: post.acceptedAnswer,
      deletedAtMillis: post.deletedAt?.millisecondsSinceEpoch,
      userDeleted: post.userDeleted,
    );
  }

  factory LocalFavoriteArchivedPost.fromJson(Map<String, dynamic> json) {
    return LocalFavoriteArchivedPost(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      username: json['username'] as String? ?? '',
      avatarTemplate: json['avatar_template'] as String? ?? '',
      animatedAvatar: json['animated_avatar'] as String?,
      cooked: json['cooked'] as String? ?? '',
      postNumber: json['post_number'] as int? ?? 0,
      postType: json['post_type'] as int? ?? 1,
      updatedAtMillis:
          json['updated_at_millis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      createdAtMillis:
          json['created_at_millis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      replyToPostNumber: json['reply_to_post_number'] as int? ?? 0,
      scoreHidden: json['score_hidden'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      bookmarkId: json['bookmark_id'] as int?,
      read: json['read'] as bool? ?? false,
      acceptedAnswer: json['accepted_answer'] as bool? ?? false,
      deletedAtMillis: json['deleted_at_millis'] as int?,
      userDeleted: json['user_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatar_template': avatarTemplate,
      'animated_avatar': animatedAvatar,
      'cooked': cooked,
      'post_number': postNumber,
      'post_type': postType,
      'updated_at_millis': updatedAtMillis,
      'created_at_millis': createdAtMillis,
      'like_count': likeCount,
      'reply_count': replyCount,
      'reply_to_post_number': replyToPostNumber,
      'score_hidden': scoreHidden,
      'bookmarked': bookmarked,
      'bookmark_id': bookmarkId,
      'read': read,
      'accepted_answer': acceptedAnswer,
      'deleted_at_millis': deletedAtMillis,
      'user_deleted': userDeleted,
    };
  }

  Post toPost() {
    return Post(
      id: id,
      name: name,
      username: username,
      avatarTemplate: avatarTemplate,
      animatedAvatar: animatedAvatar,
      cooked: cooked,
      postNumber: postNumber,
      postType: postType,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      likeCount: likeCount,
      replyCount: replyCount,
      replyToPostNumber: replyToPostNumber,
      scoreHidden: scoreHidden,
      bookmarked: bookmarked,
      bookmarkId: bookmarkId,
      read: read,
      acceptedAnswer: acceptedAnswer,
      deletedAt: deletedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedAtMillis!),
      userDeleted: userDeleted,
    );
  }
}
