import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_favorite_topic.dart';
import '../providers/local_favorites_provider.dart';
import '../widgets/topic/topic_card.dart';
import 'topic_detail_page/topic_detail_page.dart';

class LocalFavoritesPage extends ConsumerWidget {
  const LocalFavoritesPage({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本地收藏'),
        content: const Text('确定清空全部本地收藏话题吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(localFavoriteTopicsProvider.notifier).clear();
    }
  }

  void _openTopic(BuildContext context, LocalFavoriteTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TopicDetailPage(
          topicId: topic.topicId,
          initialTitle: topic.title,
          scrollToPostNumber: topic.lastReadPostNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(localFavoriteTopicsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('本地收藏夹 (${favorites.length})'),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('还没有本地收藏', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return Dismissible(
                  key: ValueKey('local-favorite-${favorite.topicId}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(localFavoriteTopicsProvider.notifier)
                        .removeByTopicId(favorite.topicId);
                  },
                  child: TopicCard(
                    topic: favorite.toTopic(),
                    onTap: () => _openTopic(context, favorite),
                  ),
                );
              },
            ),
    );
  }
}
