import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';

import '../models/local_favorite_topic.dart';
import '../models/topic.dart';
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

  LocalFavoritesNotifier(this._read)
      : super(LocalFavoritesState.empty(rootFolder: _rootFolder)) {
    _loadFromStorage();
  }

  final Ref _read;

  static const _rootFolder = LocalFavoriteFolder(
    id: rootFolderId,
    name: '收藏夹',
    parentId: '',
    createdAtMillis: 0,
  );

  static String _newFolderId() =>
      'fld_${DateTime.now().microsecondsSinceEpoch}';

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
                return LocalFavoriteTopic.fromJson({
                  ...topic.toJson(),
                  'folder_id': rootFolderId,
                });
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

    state = state.copyWith(
      topics: state.topics.map((topic) {
        if (topic.topicId != topicId) return topic;
        return LocalFavoriteTopic.fromJson({
          ...topic.toJson(),
          'folder_id': folderId,
        });
      }).toList(),
    );
    unawaited(_persist());
  }

  bool toggleFromTopic(
    Topic topic, {
    String folderId = rootFolderId,
  }) {
    final index = state.topics.indexWhere((e) => e.topicId == topic.id);

    if (index >= 0) {
      final next = [...state.topics]..removeAt(index);
      state = state.copyWith(topics: next);
      unawaited(_persist());
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
    return true;
  }

  void removeByTopicId(int topicId) {
    state = state.copyWith(
      topics: state.topics.where((e) => e.topicId != topicId).toList(),
    );
    unawaited(_persist());
  }

  void clear() {
    state = state.copyWith(topics: const []);
    unawaited(_persist());
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
