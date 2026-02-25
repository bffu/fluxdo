import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/link_launcher.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../models/draft.dart';
import '../../models/topic.dart';
import '../../utils/responsive.dart';
import '../../utils/share_utils.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/selected_topic_provider.dart';
import '../../providers/discourse_providers.dart';
import '../../providers/message_bus_providers.dart';
import '../../providers/topic_sort_provider.dart';
import '../../providers/pinned_categories_provider.dart';
import '../../services/discourse/discourse_service.dart';
import '../../services/screen_track.dart';
import '../../widgets/content/lazy_load_scope.dart';
import '../../widgets/post/post_item_skeleton.dart';
import '../../widgets/post/reply_sheet.dart';
import '../../widgets/topic/topic_progress.dart';
import '../../widgets/topic/topic_notification_button.dart';
import '../../widgets/common/emoji_text.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/content/discourse_html_content/chunked/chunked_html_content.dart';
import 'controllers/topic_detail_controller.dart';
import 'widgets/topic_detail_overlay.dart';
import 'widgets/topic_post_list.dart';
import 'widgets/topic_detail_header.dart';
import '../../widgets/layout/master_detail_layout.dart';
import '../../widgets/share/share_image_preview.dart';
import '../../widgets/share/export_sheet.dart';
import '../../widgets/search/topic_search_view.dart';
import '../../providers/topic_search_provider.dart';
import '../edit_topic_page.dart';

part 'actions/_scroll_actions.dart';
part 'actions/_user_actions.dart';
part 'actions/_filter_actions.dart';

/// 璇濋璇︽儏椤甸潰
class TopicDetailPage extends ConsumerStatefulWidget {
  final int topicId;
  final String? initialTitle;
  final int? scrollToPostNumber; // 澶栭儴鎺у埗鐨勮烦杞綅缃紙濡備粠閫氱煡璺宠浆鍒版寚瀹氭ゼ灞傦級
  final bool embeddedMode; // 宓屽叆妯″紡锛堝弻鏍忓竷灞€涓娇鐢紝涓嶆樉绀鸿繑鍥炴寜閽級
  final bool autoSwitchToMasterDetail; // 浠呭湪浠庨椤佃繘鍏ユ椂鍏佽鑷姩鍒囨崲
  final bool autoOpenReply; // 鑷姩鎵撳紑鍥炲妗嗭紙浠庤崏绋胯繘鍏ユ椂浣跨敤锛?
  final int? autoReplyToPostNumber; // 鑷姩鍥炲鐨勫笘瀛愮紪鍙凤紙浠庤崏绋胯繘鍏ユ椂浣跨敤锛?

  const TopicDetailPage({
    super.key,
    required this.topicId,
    this.initialTitle,
    this.scrollToPostNumber,
    this.embeddedMode = false,
    this.autoSwitchToMasterDetail = false,
    this.autoOpenReply = false,
    this.autoReplyToPostNumber,
  });

  @override
  ConsumerState<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends ConsumerState<TopicDetailPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// 鍞竴瀹炰緥 ID锛岀‘淇濇瘡娆℃墦寮€椤甸潰閮藉垱寤烘柊鐨?provider 瀹炰緥
  final String _instanceId = const Uuid().v4();

  /// Provider 鍙傛暟锛堢畝鍖栭噸澶嶅垱寤猴級
  TopicDetailParams get _params => TopicDetailParams(
    widget.topicId,
    postNumber: _controller.currentPostNumber,
    instanceId: _instanceId,
  );

  // Controller
  late final TopicDetailController _controller;
  late final ScreenTrack _screenTrack;

  // UI State
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _centerKey = GlobalKey();
  bool _hasFirstPost = false;
  bool _isCheckTitleVisibilityScheduled = false;
  bool _isRefreshing = false;

  /// 鏍囬鏄惁鏄剧ず锛堢敤 ValueNotifier 闅旂 AppBar 鏇存柊锛?
  final ValueNotifier<bool> _showTitleNotifier = ValueNotifier<bool>(false);
  /// AppBar 鏄惁鏈夐槾褰憋紙鐢?ValueNotifier 闅旂 AppBar 鏇存柊锛?
  final ValueNotifier<bool> _isScrolledUnderNotifier = ValueNotifier<bool>(false);
  /// 灞曞紑澶撮儴鏄惁鍙锛堢敤 ValueNotifier 闅旂 UI 鏇存柊锛?
  final ValueNotifier<bool> _isOverlayVisibleNotifier = ValueNotifier<bool>(false);
  bool _isSwitchingMode = false;  // 鍒囨崲鐑棬鍥炲妯″紡
  // 鎼滅储鐩稿叧
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final AnimationController _expandController;
  late final Animation<Offset> _animation;
  Set<int> _lastReadPostNumbers = {};
  bool? _lastCanShowDetailPane;
  bool _isAutoSwitching = false;
  bool _autoOpenReplyHandled = false; // 鏄惁宸插鐞嗚嚜鍔ㄦ墦寮€鍥炲妗?

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ))..addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        _isOverlayVisibleNotifier.value = true;
      } else if (status == AnimationStatus.dismissed) {
        _isOverlayVisibleNotifier.value = false;
      }
    });

    final trackEnabled = ref.read(currentUserProvider).value != null;

    _screenTrack = ScreenTrack(
      DiscourseService(),
      onTimingsSent: (topicId, postNumbers, highestSeen) {
        debugPrint('[TopicDetail] onTimingsSent callback triggered: topicId=$topicId, highestSeen=$highestSeen');
        // 閬嶅巻褰撳墠鎺掑簭 + 鎵€鏈夊垎绫?tab锛屾洿鏂版墍鏈夋椿璺冪殑 provider 瀹炰緥
        final currentSort = ref.read(topicSortProvider);
        final pinnedIds = ref.read(pinnedCategoriesProvider);
        final categoryIds = [null, ...pinnedIds];
        for (final categoryId in categoryIds) {
          ref.read(topicListProvider((currentSort, categoryId)).notifier).updateSeen(topicId, highestSeen);
        }
        // unread 鍒楄〃涔熼渶瑕佹洿鏂?
        if (currentSort != TopicListFilter.unread) {
          for (final categoryId in categoryIds) {
            ref.read(topicListProvider((TopicListFilter.unread, categoryId)).notifier).updateSeen(topicId, highestSeen);
          }
        }
        // 鏇存柊浼氳瘽宸茶鐘舵€侊紝瑙﹀彂 PostItem 娑堥櫎鏈鍦嗙偣
        ref.read(topicSessionProvider(topicId).notifier).markAsRead(postNumbers);
      },
    );

    if (trackEnabled) {
      _screenTrack.start(widget.topicId);
    }

    _controller = TopicDetailController(
      scrollController: AutoScrollController(),
      screenTrack: _screenTrack,
      trackEnabled: trackEnabled,
      initialPostNumber: widget.scrollToPostNumber,
      onScrolled: () {
        if (_controller.trackEnabled) {
          _screenTrack.scrolled();
        }
      },
    );

    _controller.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expandController.dispose();
    _showTitleNotifier.dispose();
    _isScrolledUnderNotifier.dispose();
    _isOverlayVisibleNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.scrollController.removeListener(_onScroll);
    _screenTrack.stop();
    _controller.dispose();
    // 娓呯悊鎼滅储鐘舵€侊紝闃叉閲嶆柊杩涘叆鏃朵粛澶勪簬鎼滅储妯″紡
    ref.read(topicSearchProvider(widget.topicId).notifier).exitSearchMode();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hasFocus = state == AppLifecycleState.resumed;
    _screenTrack.setHasFocus(hasFocus);
  }

  void _scheduleCheckTitleVisibility() {
    if (_isCheckTitleVisibilityScheduled || !mounted) return;
    _isCheckTitleVisibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isCheckTitleVisibilityScheduled = false;
      if (mounted) {
        _checkTitleVisibility();
      }
    });
  }

  void _checkTitleVisibility() {
    final barHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final ctx = _headerKey.currentContext;

    if (ctx == null) {
      if (_hasFirstPost) {
        _showTitleNotifier.value = true;
      }
      _isScrolledUnderNotifier.value = true;
    } else {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final position = box.localToGlobal(Offset.zero);
        final headerVisible = position.dy >= barHeight;
        _showTitleNotifier.value = !headerVisible;
        _isScrolledUnderNotifier.value = !_hasFirstPost || !headerVisible;
      }
    }
  }

  void _toggleExpandedHeader() {
    if (_expandController.status == AnimationStatus.completed || 
        _expandController.status == AnimationStatus.forward) {
      _expandController.reverse();
    } else {
      _expandController.forward();
    }
  }

  void _maybeSwitchToMasterDetail(bool canShowDetailPane, TopicDetail? detail) {
    if (widget.embeddedMode) {
      _lastCanShowDetailPane = canShowDetailPane;
      return;
    }

    if (!widget.autoSwitchToMasterDetail) {
      _lastCanShowDetailPane = canShowDetailPane;
      return;
    }

    final previous = _lastCanShowDetailPane;
    _lastCanShowDetailPane = canShowDetailPane;

    if (_isAutoSwitching) return;
    if (previous == null) {
      if (canShowDetailPane) {
        _switchToMasterDetail(detail);
      }
      return;
    }
    if (previous == canShowDetailPane) return;
    if (!previous && canShowDetailPane) {
      _switchToMasterDetail(detail);
    }
  }

  void _switchToMasterDetail(TopicDetail? detail) {
    _isAutoSwitching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (!navigator.canPop()) {
        _isAutoSwitching = false;
        return;
      }

      final currentPostNumber = _controller.currentPostNumber ?? widget.scrollToPostNumber;
      ref.read(selectedTopicProvider.notifier).select(
        topicId: widget.topicId,
        initialTitle: detail?.title ?? widget.initialTitle,
        scrollToPostNumber: currentPostNumber,
      );
      navigator.pop();
    });
  }

  /// 鍦ㄥぇ灞忎笂涓哄唴瀹规坊鍔犲搴︾害鏉?
  Widget _wrapWithConstraint(Widget child) {
    if (Responsive.isMobile(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
        child: child,
      ),
    );
  }

  /// 鏋勫缓甯﹀姩鐢荤殑 AppBar
  PreferredSizeWidget _buildAppBar({
    required ThemeData theme,
    required TopicDetail? detail,
    required TopicDetailNotifier notifier,
  }) {
    final searchState = ref.watch(topicSearchProvider(widget.topicId));

    // 鎼滅储妯″紡涓嬬殑 AppBar
    if (searchState.isSearchMode) {
      return AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.colorScheme.surface,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '在本话题中搜索...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          style: theme.textTheme.bodyLarge,
          textInputAction: TextInputAction.search,
          onSubmitted: (query) {
            ref.read(topicSearchProvider(widget.topicId).notifier).search(query);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchController.clear();
              ref.read(topicSearchProvider(widget.topicId).notifier).exitSearchMode();
            },
          ),
        ],
      );
    }

    // 姝ｅ父妯″紡涓嬬殑 AppBar
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ValueListenableBuilder<bool>(
        valueListenable: _showTitleNotifier,
        builder: (context, showTitle, _) => ValueListenableBuilder<bool>(
          valueListenable: _isScrolledUnderNotifier,
          builder: (context, isScrolledUnder, _) => AnimatedBuilder(
            animation: _expandController,
            builder: (context, child) {
              final targetElevation = isScrolledUnder ? 3.0 : 0.0;
              final currentElevation = targetElevation * (1.0 - _expandController.value);
              final expandProgress = _expandController.value;
              final shouldShowTitle = showTitle || !_hasFirstPost;

              return AppBar(
                automaticallyImplyLeading: !widget.embeddedMode,
                elevation: currentElevation,
                scrolledUnderElevation: currentElevation,
                shadowColor: Colors.transparent,
                surfaceTintColor: theme.colorScheme.surfaceTint.withValues(alpha:(1.0 - expandProgress).clamp(0.0, 1.0)),
                backgroundColor: theme.colorScheme.surface,
                title: _buildAppBarTitle(
                  theme: theme,
                  detail: detail,
                  shouldShowTitle: shouldShowTitle,
                  expandProgress: expandProgress,
                ),
                centerTitle: false,
                actions: _buildAppBarActions(
                  detail: detail,
                  notifier: notifier,
                  shouldShowTitle: shouldShowTitle,
                  expandProgress: expandProgress,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 鏋勫缓 AppBar 鏍囬
  Widget _buildAppBarTitle({
    required ThemeData theme,
    required TopicDetail? detail,
    required bool shouldShowTitle,
    required double expandProgress,
  }) {
    return Opacity(
      opacity: shouldShowTitle ? (1.0 - expandProgress).clamp(0.0, 1.0) : 0.0,
      child: GestureDetector(
        onTap: () {
          if (shouldShowTitle && detail != null) {
            _toggleExpandedHeader();
          }
        },
        child: Text.rich(
          TextSpan(
            style: theme.textTheme.titleMedium,
            children: [
              if (detail?.closed ?? false)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              if (detail?.hasAcceptedAnswer ?? false)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.check_box,
                      size: 18,
                      color: Colors.green,
                    ),
                  ),
                ),
              ...EmojiText.buildEmojiSpans(context, detail?.title ?? widget.initialTitle ?? '', theme.textTheme.titleMedium),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// 鏋勫缓 AppBar Actions
  List<Widget> _buildAppBarActions({
    required TopicDetail? detail,
    required TopicDetailNotifier notifier,
    required bool shouldShowTitle,
    required double expandProgress,
  }) {
    if (detail == null) {
      return [];
    }

    // 编辑话题入口：可编辑话题元数据，或编辑首帖内容
    final firstPost = detail.postStream.posts.where((p) => p.postNumber == 1).firstOrNull;
    final canEditTopic = detail.canEdit || (firstPost?.canEdit ?? false);

    return [
      // 鎼滅储鎸夐挳
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: '搜索本话题',
        onPressed: () {
          ref.read(topicSearchProvider(widget.topicId).notifier).enterSearchMode();
        },
      ),
      // 更多选项
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: '更多选项',
        onSelected: (value) {
          if (value == 'subscribe') {
            showNotificationLevelSheet(
              context,
              detail.notificationLevel,
              (level) => _handleNotificationLevelChanged(notifier, level),
            );
          } else if (value == 'edit_topic') {
            _handleEditTopic();
          }
        },
        itemBuilder: (context) => [
          if (canEditTopic)
            PopupMenuItem(
              value: 'edit_topic',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  const Text('编辑话题'),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'subscribe',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  TopicNotificationButton.getIcon(detail.notificationLevel),
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('订阅设置'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  void _showTimelineSheet(TopicDetail detail) {
    showTopicTimelineSheet(
      context: context,
      currentIndex: _controller.currentVisibleStreamIndex,
      stream: detail.postStream.stream,
      onJumpToPostId: _scrollToPostById,
      title: detail.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoggedIn = ref.watch(currentUserProvider).value != null;
    final canShowDetailPane = MasterDetailLayout.canShowBothPanesFor(context);

    ref.listen<AsyncValue<void>>(authStateProvider, (_, _) {
      if (!mounted) return;
      final stillLoggedIn = ref.read(currentUserProvider).value != null;
      if (!stillLoggedIn && _controller.trackEnabled) {
        _controller.trackEnabled = false;
      }
    });

    final params = _params;
    final detailAsync = ref.watch(topicDetailProvider(params));
    final detail = detailAsync.value;
    final notifier = ref.read(topicDetailProvider(params).notifier);

    _maybeSwitchToMasterDetail(canShowDetailPane, detail);

    // 鐩戝惉 MessageBus 浜嬩欢
    ref.listen(topicChannelProvider(widget.topicId), (previous, next) {
      // 1. reload_topic锛堣瘽棰樼姸鎬佸彉鏇达細鍏抽棴/鎵撳紑/鍥哄畾绛夛級
      if (next.reloadRequested && !(previous?.reloadRequested ?? false)) {
        ref.read(topicChannelProvider(widget.topicId).notifier).clearReloadRequest();
        _handleReloadTopic(notifier, next.refreshStreamRequested);
        return;
      }

      // 2. notification_level_change锛堥€氱煡绾у埆鍙樻洿锛?
      if (next.notificationLevelChange != null && previous?.notificationLevelChange != next.notificationLevelChange) {
        final level = TopicNotificationLevel.fromValue(next.notificationLevelChange!);
        ref.read(topicChannelProvider(widget.topicId).notifier).clearNotificationLevelChange();
        notifier.updateNotificationLevelLocally(level);
        return;
      }

      // 3. stats 鏇存柊
      if (next.statsUpdate != null && previous?.statsUpdate != next.statsUpdate) {
        notifier.applyStatsUpdate(next.statsUpdate!);
        ref.read(topicChannelProvider(widget.topicId).notifier).clearStatsUpdate();
      }

      // 4. 甯栧瓙绾у埆鏇存柊锛坈reated/revised/deleted/liked 绛夛級
      final prevLen = previous?.postUpdates.length ?? 0;
      final nextLen = next.postUpdates.length;
      if (nextLen > prevLen) {
        final newUpdates = next.postUpdates.sublist(prevLen);
        for (final update in newUpdates) {
          _handlePostUpdate(notifier, update);
        }
      }
    });

    // 棰勮В鏋愬笘瀛?HTML
    ref.listen(topicDetailProvider(params), (previous, next) {
      final posts = next.value?.postStream.posts;
      if (posts != null && posts.isNotEmpty) {
        final htmlList = posts.map((p) => p.cooked).toList();
        ChunkedHtmlContent.preloadAll(htmlList);

        final hasFirstPost = posts.first.postNumber == 1;
        if (_hasFirstPost != hasFirstPost) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _hasFirstPost = hasFirstPost);
              _scheduleCheckTitleVisibility();
            }
          });
        }

        // 鑷姩鎵撳紑鍥炲妗嗭紙浠庤崏绋胯繘鍏ユ椂锛?
        if (widget.autoOpenReply && !_autoOpenReplyHandled) {
          _autoOpenReplyHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // 濡傛灉鎸囧畾浜嗗洖澶嶅笘瀛愮紪鍙凤紝鎵惧埌瀵瑰簲鐨勫笘瀛?
              Post? replyToPost;
              if (widget.autoReplyToPostNumber != null) {
                replyToPost = posts.where(
                  (p) => p.postNumber == widget.autoReplyToPostNumber,
                ).firstOrNull;
              }
              _handleReply(replyToPost);
            }
          });
        }
      }
    });

    final searchState = ref.watch(topicSearchProvider(widget.topicId));
    final isSearchMode = searchState.isSearchMode;

    return LazyLoadScope(
      child: PopScope(
        canPop: !isSearchMode,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            // 鎼滅储妯″紡涓嬫寜杩斿洖閿紝閫€鍑烘悳绱㈣€屼笉鏄€€鍑洪〉闈?
            _searchController.clear();
            ref.read(topicSearchProvider(widget.topicId).notifier).exitSearchMode();
          }
        },
        child: Scaffold(
          appBar: _buildAppBar(
            theme: theme,
            detail: detail,
            notifier: notifier,
          ),
          body: _buildBody(context, detailAsync, detail, notifier, isLoggedIn),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<TopicDetail> detailAsync,
    TopicDetail? detail,
    TopicDetailNotifier notifier,
    bool isLoggedIn,
  ) {
    final params = _params;
    final searchState = ref.watch(topicSearchProvider(widget.topicId));
    final isSearchMode = searchState.isSearchMode;
    final archiveNotice = notifier.usingArchivedFallback
        ? (notifier.archiveNotice ?? '当前显示本地离线归档版本')
        : null;

    // 鍒濆鍔犺浇鎴栧垏鎹㈡ā寮忔椂鏄剧ず楠ㄦ灦灞?
    // 娉ㄦ剰锛氬綋 hasError 涓?true 鏃讹紝鍗充娇 isLoading 涔熶负 true锛圓syncLoading.copyWithPrevious 璇箟锛夛紝
    // 涔熷簲璇ヤ紭鍏堟樉绀洪敊璇〉闈㈣€屼笉鏄鏋跺睆
    if (_isSwitchingMode) {
      final showHeaderSkeleton = widget.scrollToPostNumber == null || widget.scrollToPostNumber == 0;
      return _wrapWithConstraint(PostListSkeleton(withHeader: showHeaderSkeleton));
    }
    
    if (detailAsync.isLoading && detail == null && !detailAsync.hasError) {
      final showHeaderSkeleton = widget.scrollToPostNumber == null || widget.scrollToPostNumber == 0;
      return _wrapWithConstraint(PostListSkeleton(withHeader: showHeaderSkeleton));
    }

    // 璺宠浆涓細绛夊緟鍖呭惈鐩爣甯栧瓙鐨勬柊鏁版嵁 - 鏄剧ず楠ㄦ灦灞?
    final jumpTarget = _controller.jumpTargetPostNumber;
    if (jumpTarget != null && detail != null) {
      final posts = detail.postStream.posts;
      // 妫€鏌ョ洰鏍囧笘瀛愭槸鍚﹀湪褰撳墠鍔犺浇鐨勮寖鍥村唴
      final hasTarget = posts.isNotEmpty &&
          posts.first.postNumber <= jumpTarget &&
          posts.last.postNumber >= jumpTarget;
      if (!hasTarget) {
        return _wrapWithConstraint(const PostListSkeleton(withHeader: false));
      }
    }

    Widget content = const SizedBox();

    if (detailAsync.hasError && detail == null) {
      // 閿欒椤甸潰
      content = CustomScrollView(
        slivers: [
          SliverErrorView(
            error: detailAsync.error!,
            onRetry: () => ref.refresh(topicDetailProvider(params)),
          ),
        ],
      );
    } else if (detail != null) {
       // 姝ｅ父鍐呭鏋勫缓 (淇濇寔鍘熸湁閫昏緫锛屼絾绠€鍖栨彁鍙?
       content = _buildPostListContent(context, detail, notifier, isLoggedIn);
    }

    if (archiveNotice != null && !isSearchMode) {
      content = Padding(
        padding: const EdgeInsets.only(top: 44),
        child: content,
      );
    }

    // Stack 缁勮
    return Stack(
        children: [
          // 浣跨敤 Offstage 淇濇寔甯栧瓙鍒楄〃瀛樺湪浣嗗湪鎼滅储妯″紡涓嬮殣钘忥紝淇濈暀婊氬姩浣嶇疆
          Offstage(
            offstage: isSearchMode,
            child: content,
          ),

          if (archiveNotice != null && !isSearchMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildArchiveNoticeBanner(context, archiveNotice),
            ),

          // 鎼滅储瑙嗗浘
          if (isSearchMode)
            TopicSearchView(
              topicId: widget.topicId,
              onJumpToPost: (postNumber) {
                // 閫€鍑烘悳绱㈡ā寮忓苟璺宠浆鍒版寚瀹氬笘瀛?
                ref.read(topicSearchProvider(widget.topicId).notifier).exitSearchMode();
                _searchController.clear();
                _scrollToPost(postNumber);
              },
            ),

          // TopicDetailOverlay (Bottom Bar)
          // 浣跨敤 ValueListenableBuilder 闅旂鐘舵€佸彉鍖栵紝閬垮厤鏁撮〉閲嶅缓
          if (detail != null && !isSearchMode)
            ValueListenableBuilder<bool>(
              valueListenable: _controller.showBottomBarNotifier,
              builder: (context, showBottomBar, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _controller.streamIndexNotifier,
                  builder: (context, currentStreamIndex, _) {
                    return TopicDetailOverlay(
                      showBottomBar: showBottomBar,
                      isLoggedIn: isLoggedIn,
                      currentStreamIndex: currentStreamIndex,
                      totalCount: detail.postStream.stream.length,
                      detail: detail,
                      onScrollToTop: _scrollToTop,
                      onShare: _shareTopic,
                      onShareAsImage: _shareAsImage,
                      onExport: _showExportSheet,
                      onOpenInBrowser: _openInBrowser,
                      onReply: () => _handleReply(null),
                      onProgressTap: () => _showTimelineSheet(detail),
                      isSummaryMode: notifier.isSummaryMode,
                      isAuthorOnlyMode: notifier.isAuthorOnlyMode,
                      isLoading: _isSwitchingMode,
                      onShowTopReplies: _handleShowTopReplies,
                      onShowAuthorOnly: _handleShowAuthorOnly,
                      onCancelFilter: _handleCancelFilter,
                    );
                  },
                );
              },
            ),

          // Expanded Header 鐩稿叧缁勪欢锛堜娇鐢?ValueListenableBuilder 闅旂鐘舵€佸彉鍖栵級
          if (!isSearchMode)
            ValueListenableBuilder<bool>(
              valueListenable: _isOverlayVisibleNotifier,
              builder: (context, isOverlayVisible, _) {
                if (!isOverlayVisible) return const SizedBox.shrink();

              return Stack(
                children: [
                  // Expanded Header Barrier
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleExpandedHeader,
                      child: FadeTransition(
                        opacity: _expandController,
                        child: Container(color: Colors.black54),
                      ),
                    ),
                  ),

                  // Expanded Header
                  if (detail != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _animation,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.7,
                          ),
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 0,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              child: TopicDetailHeader(
                                detail: detail,
                                headerKey: null,
                                onVoteChanged: _handleVoteChanged,
                                onNotificationLevelChanged: (level) => _handleNotificationLevelChanged(notifier, level),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
  }

  Widget _buildArchiveNoticeBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.95),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostListContent(
    BuildContext context,
    TopicDetail detail,
    TopicDetailNotifier notifier,
    bool isLoggedIn,
  ) {
    final posts = detail.postStream.posts;
    final hasFirstPost = posts.isNotEmpty && posts.first.postNumber == 1;
    final sessionState = ref.watch(topicSessionProvider(widget.topicId));
    final preferences = ref.watch(preferencesProvider);
  
     if (posts.isNotEmpty) {
      final readPostNumbers = <int>{};
      for (final post in posts) {
        if (post.read) {
          readPostNumbers.add(post.postNumber);
        }
      }
      readPostNumbers.addAll(sessionState.readPostNumbers);
      _updateReadPostNumbers(readPostNumbers);
    }

    // 璁＄畻鍒嗗壊绾夸綅缃紙鐑棬鍥炲妯″紡涓嬩笉鏄剧ず锛?
    int? dividerPostIndex;
    if (!notifier.isSummaryMode) {
      final lastRead = detail.lastReadPostNumber;
      final totalPosts = detail.postsCount;
      if (lastRead != null && lastRead > 3 && (totalPosts - lastRead) > 1) {
        for (int i = 0; i < posts.length; i++) {
          if (posts[i].postNumber > lastRead) {
            dividerPostIndex = i;
            break;
          }
        }
      }
    }

    // 鍒濆瀹氫綅
    if (!_controller.hasInitialScrolled && posts.isNotEmpty) {
      _controller.markInitialScrolled(posts.first.postNumber);
      if (_controller.currentPostNumber == null || _controller.currentPostNumber == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_controller.isPositioned) {
            _controller.markPositioned();
          }
        });
      } else {
        _scrollToInitialPosition(posts, dividerPostIndex);
      }
    }

    final centerPostIndex = _controller.findCenterPostIndex(posts);

    // 浣跨敤 Consumer + select 闅旂 typingUsers 鐘舵€佸彉鍖栵紝閬垮厤鏁撮〉閲嶅缓
    Widget scrollView = Consumer(
      builder: (context, ref, _) {
        final typingUsers = ref.watch(
          topicChannelProvider(widget.topicId).select((s) => s.typingUsers),
        );
        return ValueListenableBuilder<int?>(
          valueListenable: _controller.highlightNotifier,
          builder: (context, highlightPostNumber, _) {
            return TopicPostList(
              detail: detail,
              scrollController: _controller.scrollController,
              centerKey: _centerKey,
              headerKey: _headerKey,
              highlightPostNumber: highlightPostNumber,
              threadedMode: preferences.threadedCommentMode,
              blockedCommentKeywords: preferences.blockedCommentKeywords,
              typingUsers: typingUsers,
              isLoggedIn: isLoggedIn,
              hasMoreBefore: notifier.hasMoreBefore,
              hasMoreAfter: notifier.hasMoreAfter,
              isLoadingPrevious: notifier.isLoadingPrevious,
              isLoadingMore: notifier.isLoadingMore,
              centerPostIndex: centerPostIndex,
              dividerPostIndex: dividerPostIndex,
              onFirstVisiblePostChanged: _updateStreamIndexForPostNumber,
              onVisiblePostsChanged: _updateVisiblePosts,
              onJumpToPost: _scrollToPost,
              onReply: _handleReply,
              onEdit: _handleEdit,
              onShareAsImage: _sharePostAsImage,
              onRefreshPost: _handleRefreshPost,
              onVoteChanged: _handleVoteChanged,
              onNotificationLevelChanged: (level) => _handleNotificationLevelChanged(notifier, level),
              onSolutionChanged: _handleSolutionChanged,
              onScrollNotification: _controller.handleScrollNotification,
            );
          },
        );
      },
    );

    scrollView = RefreshIndicator(
      onRefresh: _handleRefresh,
      notificationPredicate: (notification) {
        if (!hasFirstPost) return false;
        if (notification.depth != 0) return false;
        return true;
      },
      child: scrollView,
    );

    // 浣跨敤 ValueListenableBuilder 闅旂瀹氫綅鐘舵€佸彉鍖栵紝閬垮厤鏁撮〉閲嶅缓
    // 浣跨敤 child 鍙傛暟閬垮厤 scrollView 閲嶅缓
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isPositionedNotifier,
      builder: (context, isPositioned, child) {
        return Opacity(
          opacity: isPositioned ? 1.0 : 0.0,
          child: child,
        );
      },
      child: scrollView,
    );

  }
}
