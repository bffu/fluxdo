import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../models/topic.dart';
import '../../../providers/message_bus_providers.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/post/post_item/post_item.dart';
import '../../../widgets/post/post_item_skeleton.dart';
import 'topic_detail_header.dart';
import 'typing_indicator.dart';

class TopicPostList extends StatefulWidget {
  final TopicDetail detail;
  final AutoScrollController scrollController;
  final GlobalKey centerKey;
  final GlobalKey headerKey;
  final int? highlightPostNumber;
  final bool threadedMode;
  final List<String> blockedCommentKeywords;
  final List<TypingUser> typingUsers;
  final bool isLoggedIn;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final bool isLoadingPrevious;
  final bool isLoadingMore;
  final int centerPostIndex;
  final int? dividerPostIndex;
  final void Function(int postNumber) onFirstVisiblePostChanged;
  final void Function(Set<int> visiblePostNumbers)? onVisiblePostsChanged;
  final void Function(int postNumber) onJumpToPost;
  final void Function(Post? replyToPost) onReply;
  final void Function(Post post) onEdit;
  final void Function(Post post)? onShareAsImage;
  final void Function(int postId) onRefreshPost;
  final void Function(int, bool) onVoteChanged;
  final void Function(TopicNotificationLevel)? onNotificationLevelChanged;
  final void Function(int postId, bool accepted)? onSolutionChanged;
  final bool Function(ScrollNotification) onScrollNotification;

  const TopicPostList({
    super.key,
    required this.detail,
    required this.scrollController,
    required this.centerKey,
    required this.headerKey,
    required this.highlightPostNumber,
    required this.threadedMode,
    required this.blockedCommentKeywords,
    required this.typingUsers,
    required this.isLoggedIn,
    required this.hasMoreBefore,
    required this.hasMoreAfter,
    required this.isLoadingPrevious,
    required this.isLoadingMore,
    required this.centerPostIndex,
    required this.dividerPostIndex,
    required this.onFirstVisiblePostChanged,
    this.onVisiblePostsChanged,
    required this.onJumpToPost,
    required this.onReply,
    required this.onEdit,
    this.onShareAsImage,
    required this.onRefreshPost,
    required this.onVoteChanged,
    this.onNotificationLevelChanged,
    this.onSolutionChanged,
    required this.onScrollNotification,
  });

  @override
  State<TopicPostList> createState() => _TopicPostListState();
}

class _TopicPostListState extends State<TopicPostList> {
  int? _lastReportedPostNumber;
  bool _isThrottled = false;

  TopicDetail get detail => widget.detail;
  AutoScrollController get scrollController => widget.scrollController;
  GlobalKey get centerKey => widget.centerKey;
  GlobalKey get headerKey => widget.headerKey;
  int? get highlightPostNumber => widget.highlightPostNumber;
  bool get threadedMode => widget.threadedMode;
  List<String> get blockedCommentKeywords => widget.blockedCommentKeywords;
  List<TypingUser> get typingUsers => widget.typingUsers;
  bool get isLoggedIn => widget.isLoggedIn;
  bool get hasMoreBefore => widget.hasMoreBefore;
  bool get hasMoreAfter => widget.hasMoreAfter;
  bool get isLoadingPrevious => widget.isLoadingPrevious;
  bool get isLoadingMore => widget.isLoadingMore;
  int get centerPostIndex => widget.centerPostIndex;
  int? get dividerPostIndex => widget.dividerPostIndex;
  void Function(int postNumber) get onJumpToPost => widget.onJumpToPost;
  void Function(Post? replyToPost) get onReply => widget.onReply;
  void Function(Post post) get onEdit => widget.onEdit;
  void Function(Post post)? get onShareAsImage => widget.onShareAsImage;
  void Function(int postId) get onRefreshPost => widget.onRefreshPost;
  void Function(int, bool) get onVoteChanged => widget.onVoteChanged;
  void Function(TopicNotificationLevel)? get onNotificationLevelChanged => widget.onNotificationLevelChanged;
  void Function(int postId, bool accepted)? get onSolutionChanged => widget.onSolutionChanged;
  bool Function(ScrollNotification) get onScrollNotification => widget.onScrollNotification;
  void Function(Set<int> visiblePostNumbers)? get onVisiblePostsChanged => widget.onVisiblePostsChanged;

  void _updateFirstVisiblePost() {
    final posts = detail.postStream.posts;
    if (posts.isEmpty || !scrollController.hasClients) return;

    final tagMap = scrollController.tagMap;
    if (tagMap.isEmpty) return;

    final viewportHeight = scrollController.position.viewportDimension;
    final topBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;

    int? firstVisiblePostIndex;
    double bestOffset = double.infinity;
    final visiblePostNumbers = <int>{};

    for (final entry in tagMap.entries) {
      final postIndex = entry.key;
      if (postIndex < 0 || postIndex >= posts.length) continue;

      final ctx = entry.value.context;
      if (!ctx.mounted) continue;

      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) continue;

      final topY = renderBox.localToGlobal(Offset.zero).dy;
      final relativeTopY = topY - topBarHeight;

      if (topY < viewportHeight && topY > topBarHeight - renderBox.size.height) {
        visiblePostNumbers.add(posts[postIndex].postNumber);

        if (relativeTopY <= 0 && relativeTopY.abs() < bestOffset) {
          bestOffset = relativeTopY.abs();
          firstVisiblePostIndex = postIndex;
        } else if (firstVisiblePostIndex == null && relativeTopY > 0 && relativeTopY < bestOffset) {
          bestOffset = relativeTopY;
          firstVisiblePostIndex = postIndex;
        }
      }
    }

    if (visiblePostNumbers.isNotEmpty) {
      onVisiblePostsChanged?.call(visiblePostNumbers);
    }

    if (firstVisiblePostIndex == null) return;
    final postNumber = posts[firstVisiblePostIndex].postNumber;
    if (postNumber == _lastReportedPostNumber) return;
    _lastReportedPostNumber = postNumber;
    widget.onFirstVisiblePostChanged(postNumber);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final result = onScrollNotification(notification);

    if (notification is ScrollUpdateNotification && !_isThrottled) {
      _isThrottled = true;
      Future.delayed(const Duration(milliseconds: 16), () {
        if (!mounted) return;
        _isThrottled = false;
        _updateFirstVisiblePost();
      });
    }

    return result;
  }

  Widget _wrapContent(BuildContext context, Widget child) {
    if (Responsive.isMobile(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
        child: child,
      ),
    );
  }

  List<_DisplayPostItem> _buildDisplayItems(List<Post> posts) {
    if (!threadedMode || posts.length <= 1) {
      return List.generate(
        posts.length,
        (index) => _DisplayPostItem(
          post: posts[index],
          rawIndex: index,
          depth: 0,
        ),
      );
    }

    final postByNumber = <int, Post>{};
    final rawIndexByPostNumber = <int, int>{};
    for (int i = 0; i < posts.length; i++) {
      postByNumber[posts[i].postNumber] = posts[i];
      rawIndexByPostNumber[posts[i].postNumber] = i;
    }

    final rootPostNumbers = <int>[];
    final childrenByParent = <int, List<int>>{};
    for (final post in posts) {
      final parentPostNumber = post.replyToPostNumber;
      final hasParent =
          parentPostNumber > 0 &&
          parentPostNumber != post.postNumber &&
          postByNumber.containsKey(parentPostNumber);
      if (!hasParent) {
        rootPostNumbers.add(post.postNumber);
        continue;
      }
      childrenByParent.putIfAbsent(parentPostNumber, () => <int>[]).add(post.postNumber);
    }

    final visited = <int>{};
    final displayItems = <_DisplayPostItem>[];

    void visit(int postNumber, int depth) {
      if (!visited.add(postNumber)) return;
      final post = postByNumber[postNumber];
      final rawIndex = rawIndexByPostNumber[postNumber];
      if (post == null || rawIndex == null) return;
      displayItems.add(_DisplayPostItem(
        post: post,
        rawIndex: rawIndex,
        depth: depth,
      ));
      final children = childrenByParent[postNumber];
      if (children == null || children.isEmpty) return;
      for (final childPostNumber in children) {
        visit(childPostNumber, depth + 1);
      }
    }

    for (final rootPostNumber in rootPostNumbers) {
      visit(rootPostNumber, 0);
    }
    for (final post in posts) {
      if (!visited.contains(post.postNumber)) {
        visit(post.postNumber, 0);
      }
    }

    return displayItems;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posts = detail.postStream.posts;
    final displayItems = _buildDisplayItems(posts);
    final hasFirstPost = posts.isNotEmpty && posts.first.postNumber == 1;
    final loadMoreSkeletonCount = calculateSkeletonCount(
      MediaQuery.of(context).size.height * 0.4,
      minCount: 2,
    );

    final displayCenterIndex = (() {
      final index = displayItems.indexWhere((item) => item.rawIndex == centerPostIndex);
      return index >= 0 ? index : 0;
    })();

    final displayDividerIndex = (() {
      if (dividerPostIndex == null) return null;
      final index = displayItems.indexWhere((item) => item.rawIndex == dividerPostIndex);
      return index >= 0 ? index : null;
    })();

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: CustomScrollView(
        controller: scrollController,
        center: centerKey,
        cacheExtent: 500,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          if (hasMoreBefore && isLoadingPrevious)
            LoadingSkeletonSliver(
              itemCount: loadMoreSkeletonCount,
              wrapContent: _wrapContent,
            ),
          if (hasFirstPost && displayCenterIndex > 0)
            SliverToBoxAdapter(
              child: _wrapContent(
                context,
                TopicDetailHeader(
                  detail: detail,
                  headerKey: headerKey,
                  onVoteChanged: onVoteChanged,
                  onNotificationLevelChanged: onNotificationLevelChanged,
                ),
              ),
            ),
          for (int i = 0; i < displayCenterIndex; i++)
            _buildPostSliver(
              context,
              theme,
              displayItems[i],
              i,
              displayDividerIndex: displayDividerIndex,
            ),
          _buildCenterSliver(
            context,
            theme,
            displayItems,
            displayCenterIndex,
            hasFirstPost,
            displayDividerIndex: displayDividerIndex,
          ),
          for (int i = displayCenterIndex + 1; i < displayItems.length; i++)
            _buildPostSliver(
              context,
              theme,
              displayItems[i],
              i,
              displayDividerIndex: displayDividerIndex,
            ),
          if (!hasMoreAfter)
            SliverToBoxAdapter(
              child: _wrapContent(
                context,
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: TypingAvatars(users: typingUsers),
                ),
              ),
            ),
          if (hasMoreAfter && isLoadingMore)
            LoadingSkeletonSliver(
              itemCount: loadMoreSkeletonCount,
              wrapContent: _wrapContent,
            ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSliver(
    BuildContext context,
    ThemeData theme,
    List<_DisplayPostItem> displayItems,
    int displayCenterIndex,
    bool hasFirstPost, {
    required int? displayDividerIndex,
  }) {
    if (displayItems.isEmpty) {
      return SliverToBoxAdapter(
        key: centerKey,
        child: const SizedBox.shrink(),
      );
    }

    if (displayCenterIndex == 0 && hasFirstPost) {
      return SliverMainAxisGroup(
        key: centerKey,
        slivers: [
          SliverToBoxAdapter(
            child: _wrapContent(
              context,
              TopicDetailHeader(
                detail: detail,
                headerKey: headerKey,
                onVoteChanged: onVoteChanged,
                onNotificationLevelChanged: onNotificationLevelChanged,
              ),
            ),
          ),
          _buildPostSliver(
            context,
            theme,
            displayItems[0],
            0,
            displayDividerIndex: displayDividerIndex,
          ),
        ],
      );
    }

    return _buildPostSliver(
      context,
      theme,
      displayItems[displayCenterIndex],
      displayCenterIndex,
      displayDividerIndex: displayDividerIndex,
      key: centerKey,
    );
  }

  Widget _buildPostSliver(
    BuildContext context,
    ThemeData theme,
    _DisplayPostItem displayItem,
    int displayIndex, {
    required int? displayDividerIndex,
    Key? key,
  }) {
    final post = displayItem.post;
    final showDivider = displayDividerIndex == displayIndex;
    final nestedIndent = (displayItem.depth * 14.0).clamp(0.0, 70.0);

    return SliverToBoxAdapter(
      key: key,
      child: _wrapContent(
        context,
        AutoScrollTag(
          key: ValueKey('post-${post.postNumber}'),
          controller: scrollController,
          index: displayItem.rawIndex,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDivider)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Text(
                    'Last read here',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(left: nestedIndent),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: displayItem.depth > 0
                        ? Border(
                            left: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: PostItem(
                    post: post,
                    topicId: detail.id,
                    highlight: highlightPostNumber == post.postNumber,
                    isTopicOwner: detail.createdBy?.username == post.username,
                    topicHasAcceptedAnswer: detail.hasAcceptedAnswer,
                    acceptedAnswerPostNumber: detail.acceptedAnswerPostNumber,
                    threadedMode: threadedMode,
                    blockedKeywords: blockedCommentKeywords,
                    onLike: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Like action is not implemented yet')),
                    ),
                    onReply: isLoggedIn ? () => onReply(post.postNumber == 1 ? null : post) : null,
                    onEdit: isLoggedIn && post.canEdit ? () => onEdit(post) : null,
                    onShareAsImage: onShareAsImage != null ? () => onShareAsImage!(post) : null,
                    onRefreshPost: onRefreshPost,
                    onJumpToPost: onJumpToPost,
                    onSolutionChanged: onSolutionChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisplayPostItem {
  final Post post;
  final int rawIndex;
  final int depth;

  const _DisplayPostItem({
    required this.post,
    required this.rawIndex,
    required this.depth,
  });
}

