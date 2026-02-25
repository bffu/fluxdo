import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../constants.dart';
import '../../../models/topic.dart';
import '../../../pages/topic_detail_page/topic_detail_page.dart';
import '../../../providers/discourse_providers.dart';
import '../../../providers/preferences_provider.dart';
import '../../../services/discourse/discourse_service.dart';
import '../../../utils/comment_keyword_filter.dart';
import '../../../utils/time_utils.dart';
import '../../content/discourse_html_content/chunked/chunked_html_content.dart';
import '../small_action_item.dart';
import '../moderator_action_item.dart';
import '../post_links.dart';
import 'widgets/post_header.dart';
import 'widgets/post_action_bar.dart';
import 'widgets/post_reply_history.dart';
import 'widgets/post_replies_list.dart';
import 'widgets/post_solution_banner.dart';
import 'widgets/post_reaction_picker.dart';
import 'widgets/post_flag_sheet.dart';
import 'widgets/post_stamp_painter.dart';

part 'actions/_reaction_actions.dart';
part 'actions/_bookmark_actions.dart';
part 'actions/_post_manage_actions.dart';
part 'actions/_menu_actions.dart';

class PostItem extends ConsumerStatefulWidget {
  final Post post;
  final int topicId;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onShareAsImage;
  final void Function(int postId)? onRefreshPost;
  final void Function(int postNumber)? onJumpToPost;
  final void Function(int postId, bool accepted)? onSolutionChanged;
  final bool highlight;
  final bool isTopicOwner;
  final bool topicHasAcceptedAnswer;
  final int? acceptedAnswerPostNumber;
  final bool threadedMode;
  final int threadDepth;
  final List<String> blockedKeywords;

  const PostItem({
    super.key,
    required this.post,
    required this.topicId,
    this.onReply,
    this.onLike,
    this.onEdit,
    this.onShareAsImage,
    this.onRefreshPost,
    this.onJumpToPost,
    this.onSolutionChanged,
    this.highlight = false,
    this.isTopicOwner = false,
    this.topicHasAcceptedAnswer = false,
    this.acceptedAnswerPostNumber,
    this.threadedMode = false,
    this.threadDepth = 0,
    this.blockedKeywords = const [],
  });

  @override
  ConsumerState<PostItem> createState() => _PostItemState();
}

class _PostItemState extends ConsumerState<PostItem> {
  final DiscourseService _service = DiscourseService();
  final GlobalKey _likeButtonKey = GlobalKey();

  // 鐐硅禐鐘舵€?
  bool _isLiking = false;

  // 涔︾鐘舵€?
  bool _isBookmarked = false;
  int? _bookmarkId;
  bool _isBookmarking = false;

  // 鍥炲簲鐘舵€?
  late List<PostReaction> _reactions;
  PostReaction? _currentUserReaction;

  // 鍥炲鍘嗗彶锛堣鍥炲鐨勫笘瀛愰摼锛?
  List<Post>? _replyHistory;
  final ValueNotifier<bool> _isLoadingReplyHistoryNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showReplyHistoryNotifier = ValueNotifier<bool>(false);

  // 鍥炲鍒楄〃锛堝洖澶嶅綋鍓嶅笘瀛愮殑甯栧瓙锛?
  final List<Post> _replies = [];
  final ValueNotifier<bool> _isLoadingRepliesNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showRepliesNotifier = ValueNotifier<bool>(false);

  // 缂撳瓨鐨勫ご鍍?widget
  Widget? _cachedAvatarWidget;
  int? _cachedPostId;

  // 瑙ｅ喅鏂规鐘舵€?
  bool _isAcceptedAnswer = false;
  bool _isTogglingAnswer = false;

  // 鍒犻櫎鐘舵€?
  bool _isDeleting = false;

  bool get _canLoadMoreReplies => _replies.length < widget.post.replyCount;

  @override
  void initState() {
    super.initState();
    _initLikeState();
  }

  @override
  void dispose() {
    _isLoadingReplyHistoryNotifier.dispose();
    _showReplyHistoryNotifier.dispose();
    _isLoadingRepliesNotifier.dispose();
    _showRepliesNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cachedAvatarWidget == null || _cachedPostId != widget.post.id) {
      _initAvatarWidget();
    }
  }

  @override
  void didUpdateWidget(PostItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _resetPostSpecificState();
      _initLikeState();
      _initAvatarWidget();
    } else {
      // 鍚屼竴甯栧瓙浣嗘暟鎹洿鏂颁簡锛堜緥濡傞€氳繃 MessageBus 鍒锋柊锛?
      // 鍙湪鏈湴娌℃湁杩涜涓殑鎿嶄綔鏃跺悓姝ュ洖搴旂姸鎬?
      if (!_isLiking) {
        _reactions = List.from(widget.post.reactions ?? []);
        _currentUserReaction = widget.post.currentUserReaction;
      }
      _isBookmarked = widget.post.bookmarked;
      _bookmarkId = widget.post.bookmarkId;
      _isAcceptedAnswer = widget.post.acceptedAnswer;
    }
  }

  void _resetPostSpecificState() {
    _isLiking = false;
    _isBookmarking = false;
    _isTogglingAnswer = false;
    _isDeleting = false;

    _replyHistory = null;
    _replies.clear();
    _isLoadingReplyHistoryNotifier.value = false;
    _showReplyHistoryNotifier.value = false;
    _isLoadingRepliesNotifier.value = false;
    _showRepliesNotifier.value = false;
  }

  void _initLikeState() {
    _reactions = List.from(widget.post.reactions ?? []);
    _currentUserReaction = widget.post.currentUserReaction;
    _isBookmarked = widget.post.bookmarked;
    _bookmarkId = widget.post.bookmarkId;
    _isAcceptedAnswer = widget.post.acceptedAnswer;
  }

  void _initAvatarWidget() {
    final theme = Theme.of(context);
    _cachedAvatarWidget = PostAvatar(
      key: ValueKey('avatar-${widget.post.id}'),
      post: widget.post,
      theme: theme,
    );
    _cachedPostId = widget.post.id;
  }

  /// 鍒囨崲鍥炲鍘嗗彶鏄剧ず
  Future<void> _toggleReplyHistory() async {
    if (_showReplyHistoryNotifier.value) {
      _showReplyHistoryNotifier.value = false;
      return;
    }

    if (_replyHistory != null) {
      _showReplyHistoryNotifier.value = true;
      return;
    }

    if (_isLoadingReplyHistoryNotifier.value) return;

    _isLoadingReplyHistoryNotifier.value = true;
    try {
      final history = await _service.getPostReplyHistory(widget.post.id);
      if (mounted) {
        _replyHistory = history;
        _isLoadingReplyHistoryNotifier.value = false;
        _showReplyHistoryNotifier.value = true;
      }
    } catch (e) {
      if (mounted) {
        _isLoadingReplyHistoryNotifier.value = false;
      }
    }
  }

  /// 鍔犺浇鍥炲鍒楄〃
  Future<void> _loadReplies() async {
    if (_isLoadingRepliesNotifier.value) return;

    _isLoadingRepliesNotifier.value = true;
    try {
      final after = _replies.isNotEmpty ? _replies.last.postNumber : 1;
      final replies = await _service.getPostReplies(widget.post.id, after: after);
      if (mounted) {
        _replies.addAll(replies);
        _isLoadingRepliesNotifier.value = false;
      }
    } catch (e) {
      if (mounted) {
        _isLoadingRepliesNotifier.value = false;
      }
    }
  }

  /// 鍒囨崲鍥炲鍒楄〃鏄剧ず
  Future<void> _toggleReplies() async {
    if (_showRepliesNotifier.value) {
      _showRepliesNotifier.value = false;
      return;
    }

    if (_replies.isNotEmpty) {
      _showRepliesNotifier.value = true;
      return;
    }

    if (_isLoadingRepliesNotifier.value) return;

    _isLoadingRepliesNotifier.value = true;
    try {
      final replies = await _service.getPostReplies(widget.post.id, after: 1);
      if (mounted) {
        _replies.addAll(replies);
        _isLoadingRepliesNotifier.value = false;
        _showRepliesNotifier.value = true;
      }
    } catch (e) {
      if (mounted) {
        _isLoadingRepliesNotifier.value = false;
      }
    }
  }

  Widget _buildCompactBadge(BuildContext context, String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesProvider);

    // 鏍规嵁甯栧瓙绫诲瀷鍒嗗彂鍒颁笉鍚岀粍浠?
    if (post.postType == PostTypes.smallAction) {
      return SmallActionItem(post: post);
    }

    if (post.postType == PostTypes.moderatorAction) {
      return ModeratorActionItem(
        post: post,
        topicId: widget.topicId,
        onReply: widget.onReply,
      );
    }

    // 关键词屏蔽：直接隐藏（不显示占位提示）
    final blockedKeywords = CommentKeywordFilter.normalizeKeywords(widget.blockedKeywords);
    if (CommentKeywordFilter.isPostBlocked(post, blockedKeywords)) {
      return const SizedBox.shrink();
    }

    final bool isWhisper = post.postType == PostTypes.whisper;

    final currentUser = ref.read(currentUserProvider).value;
    final isOwnPost = currentUser != null && currentUser.username == post.username;
    final isGuest = currentUser == null;

    final isThreadedChild = widget.threadedMode && widget.threadDepth > 0;
    final backgroundColor =
        isThreadedChild ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surface;
    final highlightColor = theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5);
    final targetColor = widget.highlight
        ? Color.alphaBlend(highlightColor, backgroundColor)
        : post.isDeleted
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
            : backgroundColor;

    return RepaintBoundary(
      child: Opacity(
        opacity: post.isDeleted ? 0.6 : 1.0,
        child: Container(
          margin: isThreadedChild ? const EdgeInsets.only(top: 6, bottom: 6, right: 8) : null,
          clipBehavior: isThreadedChild ? Clip.antiAlias : Clip.none,
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: targetColor,
            borderRadius: isThreadedChild ? BorderRadius.circular(14) : null,
            border: isThreadedChild
                ? Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    width: 0.8,
                  )
                : Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 鑳屾櫙姘村嵃鍗扮珷
              if (_isAcceptedAnswer || widget.post.canAcceptAnswer)
                Positioned(
                  right: 20,
                  top: 10,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _isAcceptedAnswer ? 0.12 : 0.05,
                      child: Transform.rotate(
                        angle: -0.15,
                        child: CustomPaint(
                          painter: PostStampPainter(
                            color: _isAcceptedAnswer ? Colors.green : theme.colorScheme.outline,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isAcceptedAnswer ? Icons.verified : Icons.help_outline,
                                  color: _isAcceptedAnswer ? Colors.green : theme.colorScheme.outline,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isAcceptedAnswer ? '已解决' : '待解决',
                                  style: TextStyle(
                                    color: _isAcceptedAnswer ? Colors.green : theme.colorScheme.outline,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    fontFamily: theme.textTheme.titleLarge?.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          // Header
          PostHeader(
            post: post,
            topicId: widget.topicId,
            isTopicOwner: widget.isTopicOwner,
            isOwnPost: isOwnPost,
            isWhisper: isWhisper,
            cachedAvatarWidget: _cachedAvatarWidget!,
            isLoadingReplyHistoryNotifier: _isLoadingReplyHistoryNotifier,
            onToggleReplyHistory: _toggleReplyHistory,
            buildCompactBadge: _buildCompactBadge,
            timeAndFloorWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      TimeUtils.formatRelativeTime(post.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -2,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final sessionState = ref.watch(topicSessionProvider(widget.topicId));
                          final isNew = !widget.post.read;
                          final isReadInSession = sessionState.readPostNumbers.contains(widget.post.postNumber);
                          final show = isNew && !isReadInSession;

                          return AnimatedOpacity(
                            opacity: show ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '#${post.postNumber}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // 琚洖澶嶅笘瀛愰瑙堬紙鍥炲鍘嗗彶锛?
          ValueListenableBuilder<bool>(
            valueListenable: _showReplyHistoryNotifier,
            builder: (context, showReplyHistory, _) {
              if (!showReplyHistory) return const SizedBox.shrink();
              return PostReplyHistory(
                replyHistory: _replyHistory,
                showReplyHistoryNotifier: _showReplyHistoryNotifier,
                onJumpToPost: widget.onJumpToPost,
              );
            },
          ),

                    const SizedBox(height: 12),

                    // Content (HTML)
                    ChunkedHtmlContent(
                      html: post.cooked,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                            preferences.contentFontScale,
                      ),
                      linkCounts: post.linkCounts,
                      mentionedUsers: post.mentionedUsers,
                      post: post,
                      topicId: widget.topicId,
                      onInternalLinkTap: (topicId, topicSlug, postNumber) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TopicDetailPage(
                              topicId: topicId,
                              initialTitle: topicSlug,
                              scrollToPostNumber: postNumber,
                            ),
                          ),
                        );
                      },
                    ),

                    // 相关链接
                    PostLinks(linkCounts: post.linkCounts),

                    // 主贴显示解决方案跳转提示
                    if (post.postNumber == 1 &&
                        widget.topicHasAcceptedAnswer &&
                        widget.acceptedAnswerPostNumber != null)
                      PostSolutionBanner(
                        acceptedAnswerPostNumber: widget.acceptedAnswerPostNumber,
                        onJumpToPost: widget.onJumpToPost,
                      ),

                    const SizedBox(height: 12),

                    // Actions
                    PostActionBar(
                      post: post,
                      isGuest: isGuest,
                      isOwnPost: isOwnPost,
                      isLiking: _isLiking,
                      reactions: _reactions,
                      currentUserReaction: _currentUserReaction,
                      likeButtonKey: _likeButtonKey,
                      replies: _replies,
                      isLoadingRepliesNotifier: _isLoadingRepliesNotifier,
                      showRepliesNotifier: _showRepliesNotifier,
                      onToggleLike: _toggleLike,
                      onShowReactionPicker: () => _showReactionPicker(context, theme),
                      onReply: widget.onReply,
                      onShowMoreMenu: () => _showMoreMenu(context, theme),
                      onToggleReplies: _toggleReplies,
                      showRepliesToggle: !widget.threadedMode,
                    ),

                    // 鍥炲鍒楄〃
                    ValueListenableBuilder<bool>(
                      valueListenable: _showRepliesNotifier,
                      builder: (context, showReplies, _) {
                        if (!showReplies || widget.threadedMode) return const SizedBox.shrink();
                        return PostRepliesList(
                          replies: _replies,
                          replyCount: widget.post.replyCount,
                          blockedKeywords: widget.blockedKeywords,
                          canLoadMore: _canLoadMoreReplies,
                          isLoadingRepliesNotifier: _isLoadingRepliesNotifier,
                          showRepliesNotifier: _showRepliesNotifier,
                          onLoadMore: _loadReplies,
                          onJumpToPost: widget.onJumpToPost,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

