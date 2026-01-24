import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../markdown_editor/markdown_editor.dart';
import '../../models/topic.dart';
import '../../services/discourse_service.dart';
import '../../services/presence_service.dart';
import '../../services/discourse_cache_manager.dart';
import '../../services/emoji_handler.dart';

/// 显示回复底部弹框
/// [topicId] 话题 ID (回复话题/帖子时必需)
/// [replyToPost] 可选，被回复的帖子
/// [targetUsername] 可选，私信目标用户名 (创建私信时必需)
/// 返回 true 表示成功发送
Future<bool> showReplySheet({
  required BuildContext context,
  int? topicId,
  Post? replyToPost,
  String? targetUsername,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReplySheet(
      topicId: topicId,
      replyToPost: replyToPost,
      targetUsername: targetUsername,
    ),
  );
  return result ?? false;
}

class ReplySheet extends ConsumerStatefulWidget {
  final int? topicId;
  final Post? replyToPost;
  final String? targetUsername;

  const ReplySheet({
    super.key,
    this.topicId,
    this.replyToPost,
    this.targetUsername,
  });

  @override
  ConsumerState<ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<ReplySheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _editorKey = GlobalKey<MarkdownEditorState>();

  bool _isSubmitting = false;
  bool _showEmojiPanel = false;

  // 表情面板高度
  static const double _emojiPanelHeight = 280.0;

  // Presence 服务（正在输入状态）
  PresenceService? _presenceService;

  bool get _isPrivateMessage => widget.targetUsername != null;

  @override
  void initState() {
    super.initState();
    EmojiHandler().init();
    
    // 初始化 Presence 服务（非私信模式）
    if (!_isPrivateMessage && widget.topicId != null) {
      _presenceService = PresenceService(DiscourseService());
      _presenceService!.enterReplyChannel(widget.topicId!);
    }
    
    // 自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // 释放 Presence 服务（会自动离开频道）
    _presenceService?.dispose();
    
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showError('请输入内容');
      return;
    }

    if (_isPrivateMessage && _titleController.text.trim().isEmpty) {
      _showError('请输入标题');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isPrivateMessage) {
        await DiscourseService().createPrivateMessage(
          targetUsernames: [widget.targetUsername!],
          title: _titleController.text.trim(),
          raw: content,
        );
      } else {
        await DiscourseService().createReply(
          topicId: widget.topicId!,
          raw: content,
          replyToPostNumber: widget.replyToPost?.postNumber,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError('发送失败: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    // DraggableScrollableSheet 提供了全屏拖拽能力
    // initialChildSize = minChildSize = maxChildSize = 0.95 即为固定高度
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.95,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // 使用 Scaffold 自动处理键盘避让 (resizeToAvoidBottomInset)
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          // PopScope 用于处理表情面板开启时的返回逻辑
          body: PopScope(
            canPop: !_showEmojiPanel,
            onPopInvokedWithResult: (bool didPop, dynamic result) async {
              if (didPop) return;
              if (_showEmojiPanel) {
                _editorKey.currentState?.closeEmojiPanel();
                setState(() => _showEmojiPanel = false);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // 1. 顶部 Header (固定)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 拖拽手柄
                      Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // 标题行
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // 标题信息
                            if (_isPrivateMessage)
                              Expanded(
                                child: Text(
                                  '发送私信给 @${widget.targetUsername}',
                                  style: theme.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else if (widget.replyToPost != null) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: widget.replyToPost!.getAvatarUrl().isNotEmpty
                                    ? discourseImageProvider(widget.replyToPost!.getAvatarUrl())
                                    : null,
                                child: widget.replyToPost!.getAvatarUrl().isEmpty
                                    ? Text(
                                        widget.replyToPost!.username[0].toUpperCase(),
                                        style: const TextStyle(fontSize: 12),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '回复 @${widget.replyToPost!.username}',
                                  style: theme.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else
                              Text(
                                '回复话题',
                                style: theme.textTheme.titleSmall,
                              ),
                            
                            if (!_isPrivateMessage && widget.replyToPost == null)
                              const Spacer(),

                            // 发送按钮
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('发送'),
                            ),
                          ],
                        ),
                      ),
                      
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ],
                  ),

                  // 私信标题输入框（仅私信模式）
                  if (_isPrivateMessage) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: '标题',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.next,
                        onTap: () {
                          if (_showEmojiPanel) {
                            _editorKey.currentState?.closeEmojiPanel();
                            setState(() => _showEmojiPanel = false);
                          }
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                    ),
                  ],

                  // 2. 编辑器区域 (使用 MarkdownEditor)
                  Expanded(
                    child: MarkdownEditor(
                      key: _editorKey,
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      hintText: '说点什么吧... (支持 Markdown)',
                      expands: true,
                      emojiPanelHeight: _emojiPanelHeight,
                      onEmojiPanelChanged: (show) {
                        setState(() => _showEmojiPanel = show);
                      },
                    ),
                  ),

                  // 底部安全区域
                  if (!_showEmojiPanel)
                    SizedBox(height: bottomPadding),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
