import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';

import '../models/local_favorite_topic.dart';
import '../models/local_favorite_topic_archive.dart';
import '../models/topic.dart';
import '../services/local_favorite_archive_service.dart';
import 'core_providers.dart';
import 'theme_provider.dart';

class LocalFavoriteFolder {
  final String id;
  final String name;
  final String parentId;
  final int createdAtMillis;

  const LocalFavoriteFolder({
    required this.id,
    required this.name,
    required this.parentId,
    required this.createdAtMillis,
  });

  factory LocalFavoriteFolder.fromJson(Map<String, dynamic> json) {
    return LocalFavoriteFolder(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? '',
      createdAtMillis:
          json['created_at_millis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at_millis': createdAtMillis,
    };
  }
}

class LocalFavoritesState {
  final List<LocalFavoriteFolder> folders;
  final List<LocalFavoriteTopic> topics;

  const LocalFavoritesState({
    required this.folders,
    required this.topics,
  });

  factory LocalFavoritesState.empty({
    required LocalFavoriteFolder rootFolder,
  }) {
    return LocalFavoritesState(
      folders: [rootFolder],
      topics: const [],
    );
  }

  LocalFavoritesState copyWith({
    List<LocalFavoriteFolder>? folders,
    List<LocalFavoriteTopic>? topics,
  }) {
    return LocalFavoritesState(
      folders: folders ?? this.folders,
      topics: topics ?? this.topics,
    );
  }
}

class LocalFavoritesNotifier extends StateNotifier<LocalFavoritesState> {
  static const rootFolderId = 'root';
  static const _storageKey = 'local_favorite_topics_v2';
  static const _legacyStorageKey = 'local_favorite_topics_v1';
  static const _archiveBatchSize = 20;

  LocalFavoritesNotifier(this._read)
      : super(LocalFavoritesState.empty(rootFolder: _rootFolder)) {
    _loadFromStorage();
  }

  final Ref _read;
  final LocalFavoriteArchiveService _archiveService = LocalFavoriteArchiveService();

  static const _rootFolder = LocalFavoriteFolder(
    id: rootFolderId,
    name: '收藏夹',
    parentId: '',
    createdAtMillis: 0,
  );

  static String _newFolderId() => 'fld_${DateTime.now().microsecondsSinceEpoch}';

  void _loadFromStorage() {
    final prefs = _read.read(sharedPreferencesProvider);
    final raw = prefs.getString(_storageKey) ?? prefs.getString(_legacyStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List<dynamic>) {
        final migratedTopics = decoded
            .map((e) {
              if (e is Map) {
                final json = Map<String, dynamic>.from(e);
                json['folder_id'] ??= rootFolderId;
                return LocalFavoriteTopic.fromJson(json);
              }
              return null;
            })
            .whereType<LocalFavoriteTopic>()
            .toList();
        state = LocalFavoritesState(
          folders: [_rootFolder],
          topics: migratedTopics,
        );
        unawaited(_persist());
        return;
      }

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final foldersRaw = map['folders'] as List<dynamic>? ?? const [];
        final topicsRaw = map['topics'] as List<dynamic>? ?? const [];

        final folders = foldersRaw
            .map((e) {
              if (e is Map) {
                return LocalFavoriteFolder.fromJson(Map<String, dynamic>.from(e));
              }
              return null;
            })
            .whereType<LocalFavoriteFolder>()
            .toList();

        final topics = topicsRaw
            .map((e) {
              if (e is Map) {
                return LocalFavoriteTopic.fromJson(Map<String, dynamic>.from(e));
              }
              return null;
            })
            .whereType<LocalFavoriteTopic>()
            .toList();

        final folderById = {
          for (final folder in folders) folder.id: folder,
        };
        folderById[rootFolderId] = _rootFolder;

        final normalizedFolders = folderById.values.toList()
          ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));

        final normalizedTopics = topics
            .map((topic) {
              if (!folderById.containsKey(topic.folderId)) {
                return topic.copyWith(folderId: rootFolderId);
              }
              return topic;
            })
            .toList();

        state = LocalFavoritesState(
          folders: normalizedFolders,
          topics: normalizedTopics,
        );
      }
    } catch (_) {
      state = LocalFavoritesState.empty(rootFolder: _rootFolder);
    }
  }

  Future<void> _persist() async {
    final prefs = _read.read(sharedPreferencesProvider);
    final json = jsonEncode({
      'folders': state.folders.map((e) => e.toJson()).toList(),
      'topics': state.topics.map((e) => e.toJson()).toList(),
    });
    await prefs.setString(_storageKey, json);
  }

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

  int _topicIndex(int topicId) {
    return state.topics.indexWhere((e) => e.topicId == topicId);
  }

  void _replaceTopic(int index, LocalFavoriteTopic topic) {
    final next = [...state.topics];
    next[index] = topic;
    state = state.copyWith(topics: next);
  }

  void _updateTopicStatus(
    int topicId, {
    bool? archivedLocally,
    int? archiveUpdatedAtMillis,
    bool? sourceUnavailable,
    String? sourceUnavailableReason,
    bool clearSourceUnavailableReason = false,
  }) {
    final index = _topicIndex(topicId);
    if (index < 0) return;
    final current = state.topics[index];
    _replaceTopic(
      index,
      current.copyWith(
        archivedLocally: archivedLocally,
        archiveUpdatedAtMillis: archiveUpdatedAtMillis,
        sourceUnavailable: sourceUnavailable,
        sourceUnavailableReason: sourceUnavailableReason,
        clearSourceUnavailableReason: clearSourceUnavailableReason,
      ),
    );
  }

  void _mergeTopicDetailIntoEntry(
    TopicDetail detail, {
    bool? archivedLocally,
    int? archiveUpdatedAtMillis,
    bool? sourceUnavailable,
    String? sourceUnavailableReason,
    bool clearSourceUnavailableReason = false,
  }) {
    final index = _topicIndex(detail.id);
    if (index < 0) return;
    final current = state.topics[index];
    final sortedPosts = [...detail.postStream.posts]
      ..sort((a, b) => a.postNumber.compareTo(b.postNumber));
    final lastPost = sortedPosts.isEmpty ? null : sortedPosts.last;

    _replaceTopic(
      index,
      current.copyWith(
        title: detail.title,
        slug: detail.slug,
        categoryId: '${detail.categoryId}',
        tags: detail.tags?.map((e) => e.name).toList() ?? current.tags,
        postsCount: detail.postsCount,
        likeCount: detail.likeCount,
        lastPosterUsername: lastPost?.username ?? current.lastPosterUsername,
        closed: detail.closed,
        lastReadPostNumber: detail.lastReadPostNumber ?? current.lastReadPostNumber,
        hasAcceptedAnswer: detail.hasAcceptedAnswer,
        canHaveAnswer: current.canHaveAnswer || detail.hasAcceptedAnswer,
        lastPostedAtMillis:
            lastPost?.createdAt.millisecondsSinceEpoch ?? current.lastPostedAtMillis,
        archivedLocally: archivedLocally,
        archiveUpdatedAtMillis: archiveUpdatedAtMillis,
        sourceUnavailable: sourceUnavailable,
        sourceUnavailableReason: sourceUnavailableReason,
        clearSourceUnavailableReason: clearSourceUnavailableReason,
      ),
    );
  }

  Future<TopicDetail> _buildCompleteDetail(
    TopicDetail detail,
  ) async {
    final stream = detail.postStream.stream;
    if (stream.isEmpty) return detail;

    final service = _read.read(discourseServiceProvider);
    final postById = <int, Post>{
      for (final post in detail.postStream.posts) post.id: post,
    };
    final missingIds = stream.where((postId) => !postById.containsKey(postId)).toList();

    for (int i = 0; i < missingIds.length; i += _archiveBatchSize) {
      final batch = missingIds.skip(i).take(_archiveBatchSize).toList();
      try {
        final chunk = await service.getPosts(detail.id, batch);
        for (final post in chunk.posts) {
          postById[post.id] = post;
        }
      } catch (e) {
        // Keep partial archive if some batches fail.
      }

      if (i + _archiveBatchSize < missingIds.length) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }

    final orderedPosts = <Post>[];
    for (final postId in stream) {
      final post = postById[postId];
      if (post != null) {
        orderedPosts.add(post);
      }
    }
    if (orderedPosts.isEmpty) {
      orderedPosts
        ..addAll(postById.values)
        ..sort((a, b) => a.postNumber.compareTo(b.postNumber));
    }

    return detail.copyWith(
      postStream: PostStream(
        posts: orderedPosts,
        stream: stream,
      ),
    );
  }

  bool containsTopic(int topicId) {
    return state.topics.any((e) => e.topicId == topicId);
  }

  LocalFavoriteFolder? folderById(String folderId) {
    for (final folder in state.folders) {
      if (folder.id == folderId) return folder;
    }
    return null;
  }

  List<LocalFavoriteFolder> subfoldersOf(String parentId) {
    final folders = state.folders
        .where((f) => f.parentId == parentId && f.id != rootFolderId)
        .toList()
      ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return folders;
  }

  List<LocalFavoriteTopic> topicsInFolder(String folderId) {
    final topics = state.topics
        .where((topic) => topic.folderId == folderId)
        .toList()
      ..sort((a, b) => b.addedAtMillis.compareTo(a.addedAtMillis));
    return topics;
  }

  String createFolder({
    required String name,
    required String parentId,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return '';
    }

    for (final folder in state.folders) {
      if (folder.parentId == parentId && folder.name == normalizedName) {
        return folder.id;
      }
    }

    final folder = LocalFavoriteFolder(
      id: _newFolderId(),
      name: normalizedName,
      parentId: parentId,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    state = state.copyWith(
      folders: [...state.folders, folder],
    );
    unawaited(_persist());
    return folder.id;
  }

  void moveTopicToFolder({
    required int topicId,
    required String folderId,
  }) {
    if (folderById(folderId) == null) return;

    final index = _topicIndex(topicId);
    if (index < 0) return;
    final current = state.topics[index];
    _replaceTopic(index, current.copyWith(folderId: folderId));
    unawaited(_persist());
  }

  bool toggleFromTopic(
    Topic topic, {
    String folderId = rootFolderId,
  }) {
    final index = _topicIndex(topic.id);

    if (index >= 0) {
      final next = [...state.topics]..removeAt(index);
      state = state.copyWith(topics: next);
      unawaited(_persist());
      unawaited(_archiveService.deleteArchive(topic.id));
      return false;
    }

    final entry = LocalFavoriteTopic.fromTopic(
      topic,
      folderId: folderById(folderId) != null ? folderId : rootFolderId,
      addedAt: DateTime.now(),
    );
    final withoutSame = state.topics.where((e) => e.topicId != topic.id).toList();
    state = state.copyWith(topics: [entry, ...withoutSame]);
    unawaited(_persist());
    unawaited(syncArchiveForTopic(topic.id));
    return true;
  }

  Future<void> syncArchiveForTopic(
    int topicId, {
    TopicDetail? seedDetail,
  }) async {
    if (!containsTopic(topicId)) return;

    try {
      final service = _read.read(discourseServiceProvider);
      final detail = seedDetail ??
          await service.getTopicDetail(topicId, postNumber: 1, trackVisit: false);
      final completedDetail = await _buildCompleteDetail(detail);
      final archive = LocalFavoriteTopicArchive.fromTopicDetail(
        completedDetail,
        lastSyncedAt: DateTime.now(),
      );
      await _archiveService.saveArchive(archive);
      _mergeTopicDetailIntoEntry(
        completedDetail,
        archivedLocally: true,
        archiveUpdatedAtMillis: archive.lastSyncedAtMillis,
        sourceUnavailable: false,
        clearSourceUnavailableReason: true,
      );
      await _persist();
    } catch (error) {
      if (seedDetail != null) {
        final archive = LocalFavoriteTopicArchive.fromTopicDetail(
          seedDetail,
          lastSyncedAt: DateTime.now(),
        );
        await _archiveService.saveArchive(archive);
        _mergeTopicDetailIntoEntry(
          seedDetail,
          archivedLocally: true,
          archiveUpdatedAtMillis: archive.lastSyncedAtMillis,
          sourceUnavailable: false,
          clearSourceUnavailableReason: true,
        );
        await _persist();
        return;
      }

      final hasArchive = await _archiveService.hasArchive(topicId);
      if (hasArchive) {
        _updateTopicStatus(
          topicId,
          archivedLocally: true,
          sourceUnavailable: true,
          sourceUnavailableReason: _reasonFromError(error),
        );
        await _persist();
      }
    }
  }

  Future<TopicDetail?> loadArchivedDetail(int topicId) async {
    final archive = await _archiveService.loadArchive(topicId);
    return archive?.toTopicDetail();
  }

  Future<void> markSourceUnavailable(
    int topicId, {
    required String reason,
  }) async {
    _updateTopicStatus(
      topicId,
      archivedLocally: true,
      sourceUnavailable: true,
      sourceUnavailableReason: reason,
    );
    await _persist();
  }

  Future<void> markSourceAvailable(int topicId) async {
    _updateTopicStatus(
      topicId,
      sourceUnavailable: false,
      clearSourceUnavailableReason: true,
    );
    await _persist();
  }

  void removeByTopicId(int topicId) {
    state = state.copyWith(
      topics: state.topics.where((e) => e.topicId != topicId).toList(),
    );
    unawaited(_persist());
    unawaited(_archiveService.deleteArchive(topicId));
  }

  void clear() {
    final topicIds = state.topics.map((e) => e.topicId).toList();
    state = state.copyWith(topics: const []);
    unawaited(_persist());
    unawaited(_archiveService.deleteArchives(topicIds));
  }
}

final localFavoritesProvider =
    StateNotifierProvider<LocalFavoritesNotifier, LocalFavoritesState>(
  LocalFavoritesNotifier.new,
);

final localFavoriteTopicsProvider = Provider<List<LocalFavoriteTopic>>((ref) {
  return ref.watch(localFavoritesProvider).topics;
});

final localFavoriteFoldersProvider = Provider<List<LocalFavoriteFolder>>((ref) {
  return ref.watch(localFavoritesProvider).folders;
});

final localFavoriteTopicIdsProvider = Provider<Set<int>>((ref) {
  final topics = ref.watch(localFavoriteTopicsProvider);
  return topics.map((e) => e.topicId).toSet();
});
