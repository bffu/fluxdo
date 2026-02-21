import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_favorite_topic.dart';
import '../models/topic.dart';
import 'core_providers.dart';
import 'local_favorites_provider.dart';
import 'message_bus/models.dart';

part 'topic_detail/_loading_methods.dart';
part 'topic_detail/_filter_methods.dart';
part 'topic_detail/_post_updates.dart';

/// Topic detail provider params.
class TopicDetailParams {
  final int topicId;
  final int? postNumber;
  final String instanceId;

  const TopicDetailParams(this.topicId, {this.postNumber, this.instanceId = ''});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicDetailParams &&
          topicId == other.topicId &&
          instanceId == other.instanceId;

  @override
  int get hashCode => Object.hash(topicId, instanceId);
}

/// Topic detail notifier with bidirectional loading.
class TopicDetailNotifier extends AsyncNotifier<TopicDetail> {
  TopicDetailNotifier(this.arg);
  final TopicDetailParams arg;

  bool _hasMoreAfter = true;
  bool _hasMoreBefore = true;
  bool _isLoadingPrevious = false;
  bool _isLoadingMore = false;
  String? _filter;
  String? _usernameFilter;
  bool _usingArchivedFallback = false;
  String? _archiveNotice;

  bool get hasMoreAfter => _hasMoreAfter;
  bool get hasMoreBefore => _hasMoreBefore;
  bool get isLoadingPrevious => _isLoadingPrevious;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSummaryMode => _filter == 'summary';
  bool get isAuthorOnlyMode => _usernameFilter != null;
  bool get _isFilteredMode => _filter != null || _usernameFilter != null;
  bool get usingArchivedFallback => _usingArchivedFallback;
  String? get archiveNotice => _archiveNotice;

  static String _reasonFromError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404 || statusCode == 410) {
        return LocalFavoriteTopic.unavailableReasonDeleted;
      }
      if (statusCode == 403) {
        return LocalFavoriteTopic.unavailableReasonForbidden;
      }
    }
    return LocalFavoriteTopic.unavailableReasonNetwork;
  }

  static String _noticeFromReason(String reason) {
    switch (reason) {
      case LocalFavoriteTopic.unavailableReasonDeleted:
        return '源帖可能已删除，当前显示本地离线归档版本';
      case LocalFavoriteTopic.unavailableReasonForbidden:
        return '当前无权限访问原帖，当前显示本地离线归档版本';
      default:
        return '网络不可用，当前显示本地离线归档版本';
    }
  }

  /// Keep boundary calculation logic consistent.
  void _updateBoundaryState(List<Post> posts, List<int> stream) {
    if (posts.isEmpty || stream.isEmpty) {
      _hasMoreBefore = false;
      _hasMoreAfter = false;
      return;
    }

    final firstPostId = posts.first.id;
    final firstIndex = stream.indexOf(firstPostId);
    _hasMoreBefore = firstIndex > 0;

    final lastPostId = posts.last.id;
    final lastIndex = stream.indexOf(lastPostId);
    _hasMoreAfter = lastIndex != -1 && lastIndex < stream.length - 1;
  }

  void _updatePostById(int postId, Post Function(Post) updater) {
    final currentDetail = state.value;
    if (currentDetail == null) return;

    final currentPosts = currentDetail.postStream.posts;
    final index = currentPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final newPosts = [...currentPosts];
    newPosts[index] = updater(currentPosts[index]);

    state = AsyncValue.data(currentDetail.copyWith(
      postStream: PostStream(posts: newPosts, stream: currentDetail.postStream.stream),
    ));
  }

  @override
  Future<TopicDetail> build() async {
    debugPrint(
      '[TopicDetailNotifier] build called with topicId=${arg.topicId}, postNumber=${arg.postNumber}',
    );
    _hasMoreAfter = true;
    _hasMoreBefore = true;
    _usingArchivedFallback = false;
    _archiveNotice = null;

    final service = ref.read(discourseServiceProvider);
    final localFavorites = ref.read(localFavoritesProvider.notifier);
    final isLocalFavorite = localFavorites.containsTopic(arg.topicId);

    try {
      final detail = await service.getTopicDetail(
        arg.topicId,
        postNumber: arg.postNumber,
        trackVisit: true,
      );

      _updateBoundaryState(detail.postStream.posts, detail.postStream.stream);

      if (isLocalFavorite) {
        unawaited(localFavorites.syncArchiveForTopic(arg.topicId, seedDetail: detail));
      }

      return detail;
    } catch (error) {
      if (!isLocalFavorite) rethrow;

      final archivedDetail = await localFavorites.loadArchivedDetail(arg.topicId);
      if (archivedDetail == null) rethrow;

      final reason = _reasonFromError(error);
      await localFavorites.markSourceUnavailable(arg.topicId, reason: reason);

      _usingArchivedFallback = true;
      _archiveNotice = _noticeFromReason(reason);
      _updateBoundaryState(archivedDetail.postStream.posts, archivedDetail.postStream.stream);
      return archivedDetail;
    }
  }
}

final topicDetailProvider =
    AsyncNotifierProvider.family.autoDispose<TopicDetailNotifier, TopicDetail, TopicDetailParams>(
  TopicDetailNotifier.new,
);

/// Topic AI summary provider.
final topicSummaryProvider = FutureProvider.autoDispose.family<TopicSummary?, int>((ref, topicId) async {
  final service = ref.read(discourseServiceProvider);
  return service.getTopicSummary(topicId);
});
