import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';
import '../models/topic.dart';
import '../models/category.dart';
import '../providers/discourse_providers.dart';
import '../providers/message_bus_providers.dart';
import '../providers/selected_topic_provider.dart';
import '../providers/pinned_categories_provider.dart';
import '../providers/topic_sort_provider.dart';
import 'webview_login_page.dart';
import 'topic_detail_page/topic_detail_page.dart';
import 'search_page.dart';
import '../widgets/common/notification_icon_button.dart';
import '../widgets/topic/topic_filter_sheet.dart';
import '../widgets/topic/topic_list_skeleton.dart';
import '../widgets/topic/sort_and_tags_bar.dart';
import '../widgets/topic/sort_dropdown.dart';
import '../widgets/topic/topic_item_builder.dart';
import '../widgets/topic/topic_notification_button.dart';
import '../widgets/topic/category_tab_manager_sheet.dart';
import '../widgets/common/tag_selection_sheet.dart';
import '../providers/app_state_refresher.dart';
import '../providers/preferences_provider.dart';
import '../widgets/layout/master_detail_layout.dart';
import '../widgets/common/error_view.dart';
import '../widgets/common/loading_dialog.dart';
import '../widgets/common/fading_edge_scroll_view.dart';

class ScrollToTopNotifier extends StateNotifier<int> {
  ScrollToTopNotifier() : super(0);

  void trigger() => state++;
}

final scrollToTopProvider = StateNotifierProvider<ScrollToTopNotifier, int>((ref) {
  return ScrollToTopNotifier();
});

/// 顶栏/底栏可见性进度（0.0 = 完全隐藏, 1.0 = 完全显示）
final barVisibilityProvider = StateProvider<double>((ref) => 1.0);

/// 帖子列表页面 - 分类 Tab + 排序下拉 + 标签 Chips
class TopicsPage extends ConsumerStatefulWidget {
  const TopicsPage({super.key});

  @override
  ConsumerState<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends ConsumerState<TopicsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _tabLength = 1; // 初始只有"全部"
  int _currentTabIndex = 0;
  final Map<int?, GlobalKey<_TopicListState>> _listKeys = {};

  /// 本地通知级别覆盖（categoryId -> level），用于设置后立即回显
  final Map<int, int> _notificationLevelOverrides = {};

  @override
  void initState() {
    super.initState();
    final pinnedIds = ref.read(pinnedCategoriesProvider);
    _tabLength = 1 + pinnedIds.length;
    _tabController = TabController(length: _tabLength, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_currentTabIndex == _tabController.index) return;
    _currentTabIndex = _tabController.index;
    // 切换 tab 时重置栏可见性
    ref.read(barVisibilityProvider.notifier).state = 1.0;
  }

  /// 检测 pinnedCategories 变化，重建 TabController
  void _syncTabsIfNeeded(List<int> pinnedIds) {
    final desiredLength = 1 + pinnedIds.length;
    if (desiredLength == _tabLength) return;

    // 清理已移除分类的 key
    final activeCategoryIds = <int?>{null, ...pinnedIds};
    _listKeys.removeWhere((key, _) => !activeCategoryIds.contains(key));

    final oldIndex = _tabController.index;
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _tabLength = desiredLength;
    _tabController = TabController(length: _tabLength, vsync: this);
    _tabController.addListener(_handleTabChange);
    _currentTabIndex = oldIndex < _tabLength ? oldIndex : 0;
    _tabController.index = _currentTabIndex;
  }


  Future<void> _goToLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const WebViewLoginPage()),
    );
    if (result == true && mounted) {
      LoadingDialog.show(context, message: '加载数据...');

      AppStateRefresher.refreshAll(ref);

      try {
        await Future.wait([
          ref.read(currentUserProvider.future),
          ref.read(topicListProvider((TopicListFilter.latest, null)).future),
        ]).timeout(const Duration(seconds: 10));
      } catch (_) {}

      if (mounted) {
        LoadingDialog.hide(context);
      }
    }
  }

  void _showTopicIdDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转到话题'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '话题 ID',
            hintText: '例如: 1095754',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final id = int.tryParse(controller.text.trim());
              Navigator.pop(context);
              if (id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicDetailPage(
                      topicId: id,
                      autoSwitchToMasterDetail: true,
                    ),
                  ),
                );
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  void _openCategoryManager() async {
    final categoryId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategoryTabManagerSheet(),
    );

    // 如果返回了 category ID，切换到对应的 Tab
    if (categoryId != null && mounted) {
      final pinnedIds = ref.read(pinnedCategoriesProvider);
      final tabIndex = pinnedIds.indexOf(categoryId);
      if (tabIndex >= 0) {
        _tabController.animateTo(tabIndex + 1); // +1 因为"全部"在 index 0
      }
    }
  }

  Future<void> _openTagSelection() async {
    final filter = ref.read(topicFilterProvider);
    final tagsAsync = ref.read(tagsProvider);
    final availableTags = tagsAsync.when(
      data: (tags) => tags,
      loading: () => <String>[],
      error: (e, s) => <String>[],
    );

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagSelectionSheet(
        availableTags: availableTags,
        selectedTags: filter.tags,
        maxTags: 99,
      ),
    );

    if (result != null && mounted) {
      ref.read(topicFilterProvider.notifier).setTags(result);
    }
  }

  /// 获取当前选中分类 Tab 对应的 Category（仅非"全部"时返回）
  Category? _getCurrentCategory(List<int> pinnedIds, Map<int, Category>? categoryMap) {
    if (_currentTabIndex == 0 || categoryMap == null) return null;
    if (_currentTabIndex - 1 >= pinnedIds.length) return null;
    final categoryId = pinnedIds[_currentTabIndex - 1];
    return categoryMap[categoryId];
  }

  /// 获取当前 tab 对应的 categoryId
  int? _currentCategoryId() {
    if (_currentTabIndex == 0) return null;
    final pinnedIds = ref.read(pinnedCategoriesProvider);
    if (_currentTabIndex - 1 < pinnedIds.length) {
      return pinnedIds[_currentTabIndex - 1];
    }
    return null;
  }

  /// 获取指定 categoryId 的 GlobalKey
  GlobalKey<_TopicListState> _getListKey(int? categoryId) {
    return _listKeys.putIfAbsent(categoryId, () => GlobalKey<_TopicListState>());
  }

  /// 构建排序栏右侧的订阅按钮（仅选中分类 Tab 时显示）
  Widget? _buildTrailing(Category? category, bool isLoggedIn) {
    if (category == null || !isLoggedIn) return null;
    // 优先使用本地覆盖值，否则取服务端返回值
    final effectiveLevel = _notificationLevelOverrides[category.id]
        ?? category.notificationLevel;
    final level = CategoryNotificationLevel.fromValue(effectiveLevel);
    return CategoryNotificationButton(
      level: level,
      onChanged: (newLevel) async {
        final oldLevel = effectiveLevel;
        // 乐观更新
        setState(() => _notificationLevelOverrides[category.id] = newLevel.value);
        try {
          final service = ref.read(discourseServiceProvider);
          await service.setCategoryNotificationLevel(category.id, newLevel.value);
        } catch (_) {
          // 失败时回退
          if (mounted) {
            setState(() {
              if (oldLevel != null) {
                _notificationLevelOverrides[category.id] = oldLevel;
              } else {
                _notificationLevelOverrides.remove(category.id);
              }
            });
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isLoggedIn = ref.watch(currentUserProvider).value != null;
    final barVisibility = ref.watch(barVisibilityProvider);
    final pinnedIds = ref.watch(pinnedCategoriesProvider);
    final categoryMapAsync = ref.watch(categoryMapProvider);
    final currentSort = ref.watch(topicSortProvider);
    final filter = ref.watch(topicFilterProvider);

    _syncTabsIfNeeded(pinnedIds);

    final currentCategory = _getCurrentCategory(pinnedIds, categoryMapAsync.value);

    // 监听滚动到顶部的通知
    ref.listen(scrollToTopProvider, (previous, next) {
      _getListKey(_currentCategoryId()).currentState?.scrollToTop();
    });

    return Column(
      children: [
        // 状态栏区域（始终存在）
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          height: topPadding,
        ),
        // 搜索栏：跟随滚动向上滑出
        ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: barVisibility,
            child: Opacity(
              opacity: barVisibility,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                height: 56,
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
                child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchPage()),
                      ),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '搜索话题...',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isLoggedIn) const NotificationIconButton(),
                  if (kDebugMode)
                    IconButton(
                      icon: const Icon(Icons.bug_report),
                      onPressed: () => _showTopicIdDialog(context),
                      tooltip: '调试：跳转话题',
                    ),
                ],
              ),
            ),
            ),
          ),
        ),
        // 分类 Tab 行（始终可见）
        GestureDetector(
          onTap: () {
            ref.read(barVisibilityProvider.notifier).state = 1.0;
            _getListKey(_currentCategoryId()).currentState?.resetScrollDirection();
          },
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: FadingEdgeScrollView(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: _buildCategoryTabs(pinnedIds, categoryMapAsync.value ?? {}),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                      dividerColor: Colors.transparent,
                      onTap: (index) {
                        if (index == _currentTabIndex) {
                          _getListKey(_currentCategoryId()).currentState?.scrollToTop();
                        }
                      },
                    ),
                  ),
                ),
                // 排序栏隐藏时，渐显排序快捷按钮
                if (barVisibility < 1.0)
                  Opacity(
                    opacity: 1.0 - barVisibility,
                    child: SortDropdown(
                      currentSort: currentSort,
                      isLoggedIn: isLoggedIn,
                      onSortChanged: (sort) {
                        ref.read(topicSortProvider.notifier).state = sort;
                      },
                      style: SortDropdownStyle.compact,
                    ),
                  ),
                // 分类浏览按钮
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.segment, size: 20),
                    onPressed: _openCategoryManager,
                    tooltip: '浏览分类',
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 排序+标签栏：跟随滚动向上滑出
        ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: barVisibility,
            child: barVisibility > 0
                ? Opacity(
                    opacity: barVisibility,
                    child: SortAndTagsBar(
                      currentSort: currentSort,
                      isLoggedIn: isLoggedIn,
                      onSortChanged: (sort) {
                        ref.read(topicSortProvider.notifier).state = sort;
                      },
                      selectedTags: filter.tags,
                      onTagRemoved: (tag) {
                        ref.read(topicFilterProvider.notifier).removeTag(tag);
                      },
                      onAddTag: _openTagSelection,
                      trailing: _buildTrailing(currentCategory, isLoggedIn),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // 列表区域（TabBarView 支持左右滑动切换，每个页面各自带圆角裁剪）
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTabPage(null),
              for (final pinnedId in pinnedIds)
                _buildTabPage(pinnedId),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建分类 Tab 列表
  List<Tab> _buildCategoryTabs(List<int> pinnedIds, Map<int, Category> categoryMap) {
    final tabs = <Tab>[const Tab(text: '全部')];
    for (final id in pinnedIds) {
      final category = categoryMap[id];
      if (category != null) {
        tabs.add(Tab(text: category.name));
      } else {
        tabs.add(Tab(text: '...'));
      }
    }
    return tabs;
  }

  /// 构建单个 tab 页面（带水平间距，圆角裁剪在列表内部处理）
  Widget _buildTabPage(int? categoryId) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: _TopicList(
        key: _getListKey(categoryId),
        categoryId: categoryId,
        onLoginRequired: _goToLogin,
      ),
    );
  }
}

/// 话题列表（每个 tab 一个实例，根据 categoryId + topicSortProvider 获取数据）
class _TopicList extends ConsumerStatefulWidget {
  final VoidCallback onLoginRequired;
  final int? categoryId;

  const _TopicList({
    super.key,
    required this.onLoginRequired,
    this.categoryId,
  });

  @override
  ConsumerState<_TopicList> createState() => _TopicListState();
}

class _TopicListState extends ConsumerState<_TopicList>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingNewTopics = false;

  @override
  bool get wantKeepAlive => true;

  /// 列表区域顶部圆角
  static const _topBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.circular(12),
  );

  /// 完成一次完整显示/隐藏过渡的滚动距离（像素）
  static const double _scrollRange = 70.0;
  double _lastDirectionChangeOffset = 0.0;
  double _visibilityAtDirectionChange = 1.0;
  ScrollDirection _currentDirection = ScrollDirection.idle;

  /// 松手后回弹动画
  late final AnimationController _snapController;
  double _snapFrom = 1.0;
  double _snapTo = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _snapController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    final t = Curves.easeOut.transform(_snapController.value);
    ref.read(barVisibilityProvider.notifier).state =
        _snapFrom + (_snapTo - _snapFrom) * t;
  }

  /// 松手后根据当前进度吸附到 0 或 1
  void _snapToNearest() {
    final current = ref.read(barVisibilityProvider);
    if (current == 0.0 || current == 1.0) return;
    if (_snapController.isAnimating) return;
    _snapFrom = current;
    _snapTo = current > 0.5 ? 1.0 : 0.0;
    _snapController.forward(from: 0.0);
  }

  void _onScroll() {
    final currentSort = ref.read(topicSortProvider);
    // 加载更多
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(topicListProvider((currentSort, widget.categoryId)).notifier).loadMore();
    }
    // 滚动方向
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.idle) return;

    // 用户继续滚动时取消回弹动画
    if (_snapController.isAnimating) {
      _snapController.stop();
    }

    final currentOffset = _scrollController.position.pixels;

    // 方向改变时，记录起点和当时的可见度
    if (direction != _currentDirection) {
      _currentDirection = direction;
      _lastDirectionChangeOffset = currentOffset;
      _visibilityAtDirectionChange = ref.read(barVisibilityProvider);
    }

    // 根据滚动距离计算进度
    final rawDelta = (currentOffset - _lastDirectionChangeOffset).abs();
    final progress = (rawDelta / _scrollRange).clamp(0.0, 1.0);

    double newVisibility;
    if (direction == ScrollDirection.forward) {
      // 向上滚动 → 渐显
      newVisibility = _visibilityAtDirectionChange +
          progress * (1.0 - _visibilityAtDirectionChange);
    } else {
      // 向下滚动 → 渐隐
      newVisibility = _visibilityAtDirectionChange -
          progress * _visibilityAtDirectionChange;
    }

    ref.read(barVisibilityProvider.notifier).state = newVisibility;
  }

  /// 外部触发显示栏时调用，重置方向追踪状态。
  void resetScrollDirection() {
    _visibilityAtDirectionChange = 1.0;
    _currentDirection = ScrollDirection.idle;
    if (_scrollController.hasClients) {
      _lastDirectionChangeOffset = _scrollController.position.pixels;
    }
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _openTopic(Topic topic) {
    final canShowDetailPane = MasterDetailLayout.canShowBothPanesFor(context);

    if (canShowDetailPane) {
      ref.read(selectedTopicProvider.notifier).select(
        topicId: topic.id,
        initialTitle: topic.title,
        scrollToPostNumber: topic.lastReadPostNumber,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicDetailPage(
          topicId: topic.id,
          initialTitle: topic.title,
          scrollToPostNumber: topic.lastReadPostNumber,
          autoSwitchToMasterDetail: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 需要
    final currentSort = ref.watch(topicSortProvider);
    final selectedTopicId = ref.watch(selectedTopicProvider).topicId;
    final providerKey = (currentSort, widget.categoryId);
    final topicsAsync = ref.watch(topicListProvider(providerKey));

    return topicsAsync.when(
      data: (topics) {
        if (topics.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              try {
                // ignore: unused_result
                await ref.refresh(topicListProvider(providerKey).future);
              } catch (_) {}
            },
            child: ClipRRect(
              borderRadius: _topBorderRadius,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('没有相关话题')),
                ],
              ),
            ),
          );
        }

        final incomingState = ref.watch(latestChannelProvider);
        final hasNewTopics = currentSort == TopicListFilter.latest
            && incomingState.hasIncomingForCategory(widget.categoryId);
        final newTopicCount = incomingState.incomingCountForCategory(widget.categoryId);
        final newTopicOffset = hasNewTopics ? 1 : 0;

        return RefreshIndicator(
          onRefresh: () async {
            try {
              // ignore: unused_result
              await ref.refresh(topicListProvider(providerKey).future);
            } catch (_) {}
            if (currentSort == TopicListFilter.latest) {
              ref.read(latestChannelProvider.notifier).clearNewTopicsForCategory(widget.categoryId);
            }
          },
          child: ClipRRect(
            borderRadius: _topBorderRadius,
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _snapToNearest();
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                itemCount: topics.length + newTopicOffset + 1,
                itemBuilder: (context, index) {
                  if (hasNewTopics && index == 0) {
                    return _buildNewTopicIndicator(context, newTopicCount, providerKey);
                  }

                  final topicIndex = index - newTopicOffset;
                  if (topicIndex >= topics.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: ref.watch(topicListProvider(providerKey).notifier).hasMore
                            ? const CircularProgressIndicator()
                            : const Text('没有更多了', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }

                  final topic = topics[topicIndex];
                  final enableLongPress = ref.watch(preferencesProvider).longPressPreview;

                  return buildTopicItem(
                    context: context,
                    topic: topic,
                    isSelected: topic.id == selectedTopicId,
                    onTap: () => _openTopic(topic),
                    enableLongPress: enableLongPress,
                  );
                },
              ),
            ),
          ),
        );
      },
      loading: () => ClipRRect(
        borderRadius: _topBorderRadius,
        child: const TopicListSkeleton(),
      ),
      error: (error, stack) => ClipRRect(
        borderRadius: _topBorderRadius,
        child: ErrorView(
          error: error,
          stackTrace: stack,
          onRetry: () => ref.refresh(topicListProvider(providerKey)),
        ),
      ),
    );
  }

  Widget _buildNewTopicIndicator(BuildContext context, int count, (TopicListFilter, int?) providerKey) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isLoadingNewTopics ? null : () async {
            setState(() {
              _isLoadingNewTopics = true;
            });
            try {
              await ref.read(topicListProvider(providerKey).notifier).silentRefresh();
              ref.read(latestChannelProvider.notifier).clearNewTopicsForCategory(providerKey.$2);

              if (mounted) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isLoadingNewTopics = false;
                });
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _isLoadingNewTopics
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '有 $count 条新话题，点击刷新',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
