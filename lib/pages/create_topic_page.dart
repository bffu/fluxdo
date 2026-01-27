import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluxdo/widgets/common/loading_spinner.dart';
import 'package:fluxdo/widgets/common/category_selection_sheet.dart';
import 'package:fluxdo/widgets/common/tag_selection_sheet.dart';
import 'package:fluxdo/widgets/markdown_editor/markdown_toolbar.dart';
import 'package:fluxdo/models/category.dart';

import 'package:fluxdo/providers/discourse_providers.dart';
import 'package:fluxdo/services/discourse_cache_manager.dart';
import 'package:fluxdo/utils/font_awesome_helper.dart';
import 'package:fluxdo/widgets/markdown_editor/markdown_renderer.dart';
import 'package:fluxdo/services/emoji_handler.dart';
import 'package:fluxdo/widgets/topic/topic_filter_sheet.dart';
import 'package:fluxdo/services/preloaded_data_service.dart';
import 'package:fluxdo/widgets/mention/mention_autocomplete.dart';
import '../constants.dart';

class CreateTopicPage extends ConsumerStatefulWidget {
  const CreateTopicPage({super.key});

  @override
  ConsumerState<CreateTopicPage> createState() => _CreateTopicPageState();
}

class _CreateTopicPageState extends ConsumerState<CreateTopicPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _toolbarKey = GlobalKey<MarkdownToolbarState>();

  Category? _selectedCategory;
  List<String> _selectedTags = [];
  bool _isSubmitting = false;
  bool _showPreview = false;
  String? _templateContent;

  final PageController _pageController = PageController();
  int _contentLength = 0;
  String _previousContentText = '';

  @override
  void initState() {
    super.initState();
    _previousContentText = _contentController.text;
    _contentController.addListener(_updateContentLength);
    _contentController.addListener(_handleContentTextChange);
    // 初始化 EmojiHandler 以支持预览
    EmojiHandler().init();
    // 从当前筛选条件自动填入分类和标签
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyCurrentFilter());
  }

  void _applyCurrentFilter() async {
    final filter = ref.read(topicFilterProvider);
    if (filter.tags.isNotEmpty) {
      setState(() => _selectedTags = List.from(filter.tags));
    }
    
    // 确定要选择的分类 ID：优先使用筛选条件中的，否则使用站点默认分类
    int? targetCategoryId = filter.categoryId;
    if (targetCategoryId == null) {
      targetCategoryId = await PreloadedDataService().getDefaultComposerCategoryId();
    }
    
    if (targetCategoryId != null && mounted) {
      // 监听 categories 加载完成
      ref.listenManual(categoriesProvider, (previous, next) {
        next.whenData((categories) {
          if (!mounted) return;
          final category = categories.where((c) => c.id == targetCategoryId).firstOrNull;
          if (category != null && category.canCreateTopic && _selectedCategory == null) {
            _onCategorySelected(category);
          }
        });
      }, fireImmediately: true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentController.removeListener(_updateContentLength);
    _contentController.removeListener(_handleContentTextChange);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }


  void _updateContentLength() {
    setState(() => _contentLength = _contentController.text.length);
  }

  /// 处理文本变化，实现智能列表续行
  void _handleContentTextChange() {
    final currentText = _contentController.text;
    final selection = _contentController.selection;

    // 只在文本增加时处理
    if (currentText.length <= _previousContentText.length) {
      _previousContentText = currentText;
      return;
    }

    // 检查是否有有效的光标位置
    if (!selection.isValid || selection.start == 0) {
      _previousContentText = currentText;
      return;
    }

    // 检查光标前的字符是否是换行符
    if (currentText[selection.start - 1] != '\n') {
      _previousContentText = currentText;
      return;
    }

    // 找到上一行的开始位置
    int prevLineStart = selection.start - 2;
    if (prevLineStart < 0) {
      _previousContentText = currentText;
      return;
    }

    // 向前查找上一行的开始
    while (prevLineStart > 0 && currentText[prevLineStart - 1] != '\n') {
      prevLineStart--;
    }

    // 提取上一行的内容
    final prevLine = currentText.substring(prevLineStart, selection.start - 1);

    // 检测无序列表
    final unorderedMatch = RegExp(r'^(\s*)([-*+])\s+(.*)$').firstMatch(prevLine);
    if (unorderedMatch != null) {
      final indent = unorderedMatch.group(1)!;
      final marker = unorderedMatch.group(2)!;
      final content = unorderedMatch.group(3)!;

      if (content.isEmpty) {
        // 空列表项，移除列表标记
        final newText = currentText.replaceRange(prevLineStart, selection.start, '\n');
        _previousContentText = newText;
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart + 1),
        );
      } else {
        // 非空列表项，添加新的列表标记
        final prefix = '$indent$marker ';
        final newText = currentText.replaceRange(selection.start, selection.start, prefix);
        _previousContentText = newText;
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + prefix.length),
        );
      }
      return;
    }

    // 检测有序列表
    final orderedMatch = RegExp(r'^(\s*)(\d+)\.\s+(.*)$').firstMatch(prevLine);
    if (orderedMatch != null) {
      final indent = orderedMatch.group(1)!;
      final number = int.parse(orderedMatch.group(2)!);
      final content = orderedMatch.group(3)!;

      if (content.isEmpty) {
        // 空列表项，移除列表标记
        final newText = currentText.replaceRange(prevLineStart, selection.start, '\n');
        _previousContentText = newText;
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart + 1),
        );
      } else {
        // 非空列表项，添加新的列表标记（数字递增）
        final prefix = '$indent${number + 1}. ';
        final newText = currentText.replaceRange(selection.start, selection.start, prefix);
        _previousContentText = newText;
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + prefix.length),
        );
      }
      return;
    }

    _previousContentText = currentText;
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('0xFF$hex'));
    }
    return Colors.grey;
  }

  void _onCategorySelected(Category category) {
    setState(() => _selectedCategory = category);

    final currentContent = _contentController.text.trim();
    if (currentContent.isEmpty ||
        (_templateContent != null && currentContent == _templateContent!.trim())) {
      if (category.topicTemplate != null && category.topicTemplate!.isNotEmpty) {
        _contentController.text = category.topicTemplate!;
        _templateContent = category.topicTemplate;
      } else {
        _contentController.clear();
        _templateContent = null;
      }
    }
  }

  void _togglePreview() {
    if (_showPreview) {
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      FocusScope.of(context).unfocus(); // 收起键盘
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    if (_selectedCategory!.minimumRequiredTags > 0 &&
        _selectedTags.length < _selectedCategory!.minimumRequiredTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('此分类至少需要 ${_selectedCategory!.minimumRequiredTags} 个标签')),
      );
      return;
    }

    // 标签组要求的完整验证由后端 API 处理
    // 这里只做基本提示，提交时后端会验证并返回错误信息

    if (_templateContent != null &&
        _contentController.text.trim() == _templateContent!.trim()) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('您尚未修改分类模板内容，确定要发布吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定发布'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(discourseServiceProvider);
      final topicId = await service.createTopic(
        title: _titleController.text.trim(),
        raw: _contentController.text,
        categoryId: _selectedCategory!.id,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(topicId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('创建失败: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 显示分类选择底部弹窗
  void _showCategoryPicker(List<Category> categories) async {
    final result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategorySelectionSheet(
        categories: categories,
        selectedCategory: _selectedCategory,
      ),
    );
    
    if (result != null) {
      _onCategorySelected(result);
    }
  }

  /// 显示标签选择底部弹窗
  void _showTagPicker(List<String> availableTags) async {
    final minTags = _selectedCategory?.minimumRequiredTags ?? 0;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagSelectionSheet(
        categoryId: _selectedCategory?.id,
        availableTags: availableTags,
        selectedTags: _selectedTags,
        maxTags: 5,
        minTags: minTags,
      ),
    );
    
    if (result != null) {
      setState(() => _selectedTags = result);
    }
  }

  /// 构建分类选择触发器
  Widget _buildCategoryTrigger(List<Category> categories) {
    final theme = Theme.of(context);
    final category = _selectedCategory;
    
    if (category == null) {
      return Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showCategoryPicker(categories),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.category_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  '选择分类',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    final color = _parseColor(category.color);
    IconData? faIcon = FontAwesomeHelper.getIcon(category.icon);
    String? logoUrl = category.uploadedLogo;

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _showCategoryPicker(categories),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (faIcon != null)
                FaIcon(faIcon, size: 14, color: color)
              else if (logoUrl != null && logoUrl.isNotEmpty)
                Image(
                  image: discourseImageProvider(
                    logoUrl.startsWith('http') ? logoUrl : '${AppConstants.baseUrl}$logoUrl',
                  ),
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  errorBuilder: (context, e, s) => _buildDot(color),
                )
              else
                _buildDot(color),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签展示和触发区域
  Widget _buildTagsArea(List<String> allTags) {
    final theme = Theme.of(context);
    final minTags = _selectedCategory?.minimumRequiredTags ?? 0;
    final currentCount = _selectedTags.length;

    // 根据选中的分类过滤可用标签
    List<String> availableTags = allTags;
    if (_selectedCategory != null) {
      final category = _selectedCategory!;
      if (category.allowedTags.isNotEmpty || category.allowedTagGroups.isNotEmpty) {
        // 如果分类限制了标签，只显示允许的标签
        availableTags = allTags.where((tag) {
          // 检查是否在允许的标签列表中
          if (category.allowedTags.contains(tag)) return true;
          // 如果允许全局标签，也包含
          if (category.allowGlobalTags) return true;
          return false;
        }).toList();
      }
    }

    // 检查标签组要求
    // 直接使用分类的 requiredTagGroups 配置
    final missingRequirements = <String>[];
    bool isGroupsSatisfied = true;
    
    if (_selectedCategory != null && _selectedCategory!.requiredTagGroups.isNotEmpty) {
      // 暂时简化逻辑：如果有 requiredTagGroups 且没有选择任何标签，显示第一个组的要求
      // 完整的计算需要在 TagSelectionSheet 中通过 API 返回的 required_tag_group 来处理
      if (_selectedTags.isEmpty) {
        for (final req in _selectedCategory!.requiredTagGroups) {
          isGroupsSatisfied = false;
          missingRequirements.add('从 ${req.name} 选择 ${req.minCount} 个');
        }
      }
      // 注意：精确的满足检查由后端 API 在提交时验证
    }

    final isSatisfied = currentCount >= minTags && isGroupsSatisfied;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._selectedTags.map((tag) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tag, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                tag,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTags.remove(tag);
                  });
                },
                child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        )),

        // 添加/编辑标签按钮
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTagPicker(availableTags),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSatisfied
                      ? theme.colorScheme.outline.withValues(alpha: 0.2)
                      : theme.colorScheme.error.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                ),
                color: isSatisfied ? null : theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedTags.isEmpty ? Icons.add : Icons.edit_outlined,
                    size: 16,
                    color: isSatisfied ? theme.colorScheme.primary : theme.colorScheme.error,
                  ),
                  if (_selectedTags.isEmpty || !isSatisfied) ...[
                    const SizedBox(width: 4),
                    Text(
                      _getButtonText(minTags, currentCount, missingRequirements),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSatisfied
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getButtonText(int minTags, int currentCount, List<String> missingReqs) {
    // 优先显示标签组要求
    if (missingReqs.isNotEmpty) {
      // 只显示第一个未满足的标签组要求
      return missingReqs.first;
    }
    // 然后显示最小标签数要求
    if (currentCount < minTags) {
      final remaining = minTags - currentCount;
      return _selectedTags.isEmpty
          ? '至少选择 $minTags 个标签'
          : '还需 $remaining 个标签';
    }
    return '添加标签';
  }


  Widget _buildDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final canTagTopics = ref.watch(canTagTopicsProvider).value ?? false;
    final theme = Theme.of(context);
    
    final showEmojiPanel = _toolbarKey.currentState?.showEmojiPanel ?? false;

    return PopScope(
      canPop: !showEmojiPanel,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        _toolbarKey.currentState?.closeEmojiPanel();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 关键：防止键盘顶起页面，因为我们自己处理了布局
        appBar: AppBar(
          title: const Text('创建话题'),
          scrolledUnderElevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('发布'),
              ),
            ),
          ],
        ),
        body: categoriesAsync.when(
          data: (categories) {
            return Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _showPreview = index == 1;
                      });
                       if (_showPreview) {
                         FocusScope.of(context).unfocus();
                         _toolbarKey.currentState?.closeEmojiPanel();
                       }
                    },
                    children: [
                      // Page 0: 编辑模式
                      Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          children: [
                            // 标题输入
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: '键入一个吸引人的标题...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              maxLines: null,
                              maxLength: 200,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return '请输入标题';
                                if (value.trim().length < 5) return '标题至少需要 5 个字符';
                                return null;
                              },
                              onTap: () {
                                _toolbarKey.currentState?.closeEmojiPanel();
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // 元数据区域 (分类 + 标签)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCategoryTrigger(categories),
                                if (canTagTopics) ...[
                                  const SizedBox(height: 12),
                                  tagsAsync.when(
                                    data: (tags) => _buildTagsArea(tags),
                                    loading: () => const SizedBox.shrink(),
                                    error: (e, s) => const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
      
                            const SizedBox(height: 20),
                            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            const SizedBox(height: 20),
      
                            // 内容区域 & 字符计数
                            MentionAutocomplete(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              dataSource: (term) => ref.read(discourseServiceProvider).searchUsers(
                                term: term,
                                categoryId: _selectedCategory?.id,
                                includeGroups: true,
                              ),
                              child: TextFormField(
                                controller: _contentController,
                                focusNode: _contentFocusNode,
                                maxLines: null,
                                minLines: 12,
                                decoration: InputDecoration(
                                  hintText: '正文内容 (支持 Markdown)...',
                                  border: InputBorder.none,
                                  helperText: _templateContent != null ? '已填充分类模板' : null,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.6,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                ),
                                validator: (value) {
                                   if (value == null || value.trim().isEmpty) return '请输入内容';
                                   if (value.trim().length < 10) return '内容至少需要 10 个字符';
                                   return null;
                                },
                                onTap: () {
                                   _toolbarKey.currentState?.closeEmojiPanel();
                                },
                              ),
                            ),
                            const SizedBox(height: 40),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$_contentLength 字符',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
  
                      // Page 1: 预览模式
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                           Text(
                              _titleController.text.isEmpty ? '（无标题）' : _titleController.text,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_selectedCategory != null) _buildCategoryTrigger(categories), // 复用样式
                                ..._selectedTags.map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '# $t', 
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    )
                                  ),
                                )),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Divider(height: 1),
                            ),
                            if (_contentController.text.isEmpty)
                               Text(
                                 '（无内容）', 
                                 style: TextStyle(color: theme.colorScheme.onSurfaceVariant)
                               )
                            else
                              MarkdownBody(data: _contentController.text),
                          ],
                        )
                      ),
                    ],
                  ),
                ),
                
                // 底部工具栏区域
                Padding(
                   padding: EdgeInsets.only(
                     bottom: MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom,
                   ),
                   child: MarkdownToolbar(
                     key: _toolbarKey,
                     controller: _contentController,
                     focusNode: _contentFocusNode,
                     isPreview: _showPreview,
                     onTogglePreview: _togglePreview,
                     emojiPanelHeight: 350,
                   ),
                ),
              ],
            );
          },
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(child: Text('加载分类失败: $err')),
        ),
      ),
    );
  }
}
