import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';

import '../models/local_favorite_topic.dart';
import '../models/topic.dart';
import 'theme_provider.dart';

class LocalFavoritesNotifier extends StateNotifier<List<LocalFavoriteTopic>> {
  static const _storageKey = 'local_favorite_topics_v1';

  LocalFavoritesNotifier(this._read) : super(const []) {
    _loadFromStorage();
  }

  final Ref _read;

  void _loadFromStorage() {
    final prefs = _read.read(sharedPreferencesProvider);
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .map((e) {
            if (e is Map) {
              return LocalFavoriteTopic.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<LocalFavoriteTopic>()
          .toList()
        ..sort((a, b) => b.addedAtMillis.compareTo(a.addedAtMillis));
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persist() async {
    final prefs = _read.read(sharedPreferencesProvider);
    final json = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  bool containsTopic(int topicId) {
    return state.any((e) => e.topicId == topicId);
  }

  bool toggleFromTopic(Topic topic) {
    final now = DateTime.now();
    final index = state.indexWhere((e) => e.topicId == topic.id);

    if (index >= 0) {
      final next = [...state]..removeAt(index);
      state = next;
      unawaited(_persist());
      return false;
    }

    final entry = LocalFavoriteTopic.fromTopic(topic, addedAt: now);
    final withoutSame = state.where((e) => e.topicId != topic.id).toList();
    state = [entry, ...withoutSame];
    unawaited(_persist());
    return true;
  }

  void removeByTopicId(int topicId) {
    state = state.where((e) => e.topicId != topicId).toList();
    unawaited(_persist());
  }

  void clear() {
    state = const [];
    unawaited(_persist());
  }
}

final localFavoriteTopicsProvider =
    StateNotifierProvider<LocalFavoritesNotifier, List<LocalFavoriteTopic>>(
  LocalFavoritesNotifier.new,
);

final localFavoriteTopicIdsProvider = Provider<Set<int>>((ref) {
  final topics = ref.watch(localFavoriteTopicsProvider);
  return topics.map((e) => e.topicId).toSet();
});
