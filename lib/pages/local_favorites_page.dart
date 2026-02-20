import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_favorite_topic.dart';
import '../providers/local_favorites_provider.dart';
import '../widgets/topic/topic_card.dart';
import 'topic_detail_page/topic_detail_page.dart';

class LocalFavoritesPage extends ConsumerStatefulWidget {
  const LocalFavoritesPage({super.key});

  @override
  ConsumerState<LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends ConsumerState<LocalFavoritesPage> {
  String _currentFolderId = LocalFavoritesNotifier.rootFolderId;

  Future<void> _confirmClearAll(BuildContext context) async {
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
      ref.read(localFavoritesProvider.notifier).clear();
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建子文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入文件夹名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (!mounted || name == null || name.trim().isEmpty) return;

    final folderId = ref.read(localFavoritesProvider.notifier).createFolder(
          name: name,
          parentId: _currentFolderId,
        );

    if (folderId.isNotEmpty) {
      setState(() {
        _currentFolderId = folderId;
      });
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

  Future<void> _showMoveToFolderSheet(int topicId) async {
    final state = ref.read(localFavoritesProvider);
    final folderMap = {
      for (final folder in state.folders) folder.id: folder,
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('移动到文件夹'),
              ),
              for (final folder in state.folders)
                ListTile(
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(_buildFolderPath(folder.id, folderMap)),
                  onTap: () {
                    ref.read(localFavoritesProvider.notifier).moveTopicToFolder(
                          topicId: topicId,
                          folderId: folder.id,
                        );
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static String _buildFolderPath(
    String folderId,
    Map<String, LocalFavoriteFolder> folderMap,
  ) {
    final names = <String>[];
    var cursor = folderId;
    var guard = 0;

    while (folderMap.containsKey(cursor) && guard < 64) {
      final folder = folderMap[cursor]!;
      names.add(folder.name);
      if (folder.parentId.isEmpty) break;
      cursor = folder.parentId;
      guard++;
    }

    return names.reversed.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localFavoritesProvider);
    final notifier = ref.read(localFavoritesProvider.notifier);

    final folderMap = {
      for (final folder in state.folders) folder.id: folder,
    };

    if (!folderMap.containsKey(_currentFolderId)) {
      _currentFolderId = LocalFavoritesNotifier.rootFolderId;
    }

    final currentFolder = folderMap[_currentFolderId]!;
    final parentFolder = folderMap[currentFolder.parentId];

    final subfolders = notifier.subfoldersOf(_currentFolderId);
    final topics = notifier.topicsInFolder(_currentFolderId);

    return Scaffold(
      appBar: AppBar(
        leading: _currentFolderId == LocalFavoritesNotifier.rootFolderId
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '返回上级文件夹',
                onPressed: () {
                  setState(() {
                    _currentFolderId =
                        parentFolder?.id ?? LocalFavoritesNotifier.rootFolderId;
                  });
                },
              ),
        title: Text(_buildFolderPath(_currentFolderId, folderMap)),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: '新建子文件夹',
            onPressed: _showCreateFolderDialog,
          ),
          if (_currentFolderId == LocalFavoritesNotifier.rootFolderId &&
              state.topics.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空全部收藏',
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
      body: (subfolders.isEmpty && topics.isEmpty)
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('当前文件夹为空', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: subfolders.length + topics.length,
              itemBuilder: (context, index) {
                if (index < subfolders.length) {
                  final folder = subfolders[index];
                  final childCount =
                      notifier.topicsInFolder(folder.id).length +
                          notifier.subfoldersOf(folder.id).length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.folder_rounded),
                      title: Text(folder.name),
                      subtitle: Text('$childCount 项'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        setState(() {
                          _currentFolderId = folder.id;
                        });
                      },
                    ),
                  );
                }

                final topic = topics[index - subfolders.length];
                return Dismissible(
                  key: ValueKey('local-favorite-${topic.topicId}'),
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
                        .read(localFavoritesProvider.notifier)
                        .removeByTopicId(topic.topicId);
                  },
                  child: TopicCard(
                    topic: topic.toTopic(),
                    onTap: () => _openTopic(context, topic),
                    onLongPress: () => _showMoveToFolderSheet(topic.topicId),
                  ),
                );
              },
            ),
    );
  }
}
