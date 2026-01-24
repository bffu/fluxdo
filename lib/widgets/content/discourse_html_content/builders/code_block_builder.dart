import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../../pages/image_viewer_page.dart';
import '../../../../services/highlighter_service.dart';
import '../../../../services/discourse_cache_manager.dart';
import '../../lazy_load_scope.dart';

/// 构建代码块
Widget buildCodeBlock({
  required BuildContext context,
  required ThemeData theme,
  required dynamic codeElement,
}) {
  final className = codeElement.className as String;
  // 检测 mermaid 代码块
  if (className.contains('lang-mermaid')) {
    return _MermaidWidget(codeElement: codeElement);
  }
  return _CodeBlockWidget(codeElement: codeElement);
}

class _CodeBlockWidget extends StatefulWidget {
  final dynamic codeElement;
  const _CodeBlockWidget({required this.codeElement});

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  final _vController = ScrollController();
  final _hController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      final text = widget.codeElement.text as String;
      final className = widget.codeElement.className as String;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      String? language;
      String displayLanguage = 'TEXT';
      if (className.isNotEmpty) {
        final match = RegExp(r'lang-(\w+)').firstMatch(className);
        if (match != null) {
          language = match.group(1);
          displayLanguage = language!.toUpperCase();
        }
      }

      final bgColor = isDark ? const Color(0xff282a36) : const Color(0xfff6f8fa);
      final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
      final thumbColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);

      final codeContent = HighlighterService.instance.buildHighlightView(
        text,
        language: language,
        isDark: isDark,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.all(12),
      );

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayLanguage,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制代码'), duration: Duration(seconds: 1)),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '复制',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: RawScrollbar(
                  controller: _vController,
                  thumbVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(2),
                  padding: const EdgeInsets.only(right: 2, top: 2, bottom: 2),
                  thumbColor: thumbColor,
                  child: SingleChildScrollView(
                    controller: _vController,
                    scrollDirection: Axis.vertical,
                    child: RawScrollbar(
                      controller: _hController,
                      thumbVisibility: true,
                      thickness: 4,
                      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
                      radius: const Radius.circular(2),
                      thumbColor: thumbColor,
                      child: SingleChildScrollView(
                        controller: _hController,
                        scrollDirection: Axis.horizontal,
                        child: codeContent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('=== Code Block Error ===\nError: $e\nStackTrace: $stackTrace');
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('代码块渲染失败: $e', style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      );
    }
  }
}

/// Mermaid 图表组件 - 使用 mermaid.ink 服务端渲染
class _MermaidWidget extends StatefulWidget {
  final dynamic codeElement;
  const _MermaidWidget({required this.codeElement});

  @override
  State<_MermaidWidget> createState() => _MermaidWidgetState();
}

class _MermaidWidgetState extends State<_MermaidWidget> with SingleTickerProviderStateMixin {
  bool _showCode = false;
  bool _shouldLoad = false;
  bool _initialized = false;
  int _retryCount = 0;
  final _vController = ScrollController();
  final _hController = ScrollController();
  AnimationController? _shimmerController;

  String get _cacheKey {
    final text = widget.codeElement.text as String;
    return 'mermaid-${text.hashCode}';
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (LazyLoadScope.isLoaded(context, _cacheKey)) {
        _shouldLoad = true;
        _shimmerController?.stop();
      }
    }
  }

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    _shimmerController?.dispose();
    super.dispose();
  }

  void _triggerLoad() {
    if (!_shouldLoad) {
      LazyLoadScope.markLoaded(context, _cacheKey);
      // 不停止动画，让 shimmer 在图片加载期间继续显示
      setState(() => _shouldLoad = true);
    }
  }

  /// 构建 mermaid.ink URL
  String _buildMermaidInkUrl(String code, bool isDark, {int? width}) {
    final encoded = base64Url.encode(utf8.encode(code));
    final theme = isDark ? 'dark' : 'default';
    final bgColor = isDark ? '282a36' : 'f6f8fa';
    var url = 'https://mermaid.ink/img/$encoded?theme=$theme&bgColor=$bgColor';
    if (width != null) url += '&width=$width';
    return url;
  }

  void _retry() {
    setState(() => _retryCount++);
  }

  Widget _buildShimmerPlaceholder(ThemeData theme, {bool withMargin = true}) {
    final controller = _shimmerController;
    if (controller == null) return const SizedBox(height: 100);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          height: 100,
          margin: withMargin ? const EdgeInsets.all(12) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * controller.value, 0),
              end: Alignment(-0.5 + 2.0 * controller.value, 0),
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.codeElement.text as String;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff282a36) : const Color(0xfff6f8fa);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
    final thumbColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);
    final imageUrl = _buildMermaidInkUrl(text, isDark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: bgColor,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _showCode = !_showCode),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_showCode ? Icons.auto_graph : Icons.code, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(_showCode ? '图表' : '代码', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制代码'), duration: Duration(seconds: 1)));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.copy, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          // 内容区域
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
            child: _showCode
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: RawScrollbar(
                      controller: _vController,
                      thumbVisibility: true,
                      thickness: 4,
                      radius: const Radius.circular(2),
                      thumbColor: thumbColor,
                      child: SingleChildScrollView(
                        controller: _vController,
                        child: RawScrollbar(
                          controller: _hController,
                          thumbVisibility: true,
                          thickness: 4,
                          thumbColor: thumbColor,
                          child: SingleChildScrollView(
                            controller: _hController,
                            scrollDirection: Axis.horizontal,
                            child: HighlighterService.instance.buildHighlightView(
                              text,
                              language: 'mermaid',
                              isDark: isDark,
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : _shouldLoad
                    ? GestureDetector(
                        onTap: () {
                          final hdUrl = _buildMermaidInkUrl(text, isDark, width: 2000);
                          ImageViewerPage.open(context, hdUrl);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            key: ValueKey('$imageUrl-$_retryCount'),
                            imageUrl: imageUrl,
                            cacheManager: ExternalImageCacheManager(),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => _buildShimmerPlaceholder(theme, withMargin: false),
                            errorWidget: (context, url, error) => Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                                  const SizedBox(height: 8),
                                  Text('图表加载失败', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _retry,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('重试'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : VisibilityDetector(
                        key: Key('mermaid-$_cacheKey'),
                        onVisibilityChanged: (info) {
                          if (!_shouldLoad && info.visibleFraction > 0.01) {
                            _triggerLoad();
                          }
                        },
                        child: _buildShimmerPlaceholder(theme),
                      ),
          ),
        ],
      ),
    );
  }
}
