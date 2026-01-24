import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../lazy_load_scope.dart';

/// 懒加载图片组件
///
/// 只有当图片进入视口时才开始加载，减少内存和网络占用
class LazyImage extends StatefulWidget {
  final ImageProvider imageProvider;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String heroTag;
  final VoidCallback? onTap;

  /// 缓存 key（用于判断是否已加载，默认使用 heroTag）
  final String? cacheKey;

  /// 可见比例阈值，超过此值开始加载（0.0 - 1.0）
  final double visibilityThreshold;

  const LazyImage({
    super.key,
    required this.imageProvider,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    required this.heroTag,
    this.onTap,
    this.cacheKey,
    this.visibilityThreshold = 0.01,
  });

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> with SingleTickerProviderStateMixin {
  bool _shouldLoad = false;
  bool _initialized = false;
  AnimationController? _shimmerController;

  String get _cacheKey => widget.cacheKey ?? widget.heroTag;

  @override
  void initState() {
    super.initState();
    // 先创建动画控制器，后面根据缓存状态决定是否使用
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
      // 检查作用域缓存
      if (LazyLoadScope.isLoaded(context, _cacheKey)) {
        _shouldLoad = true;
        _shimmerController?.stop();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  void _triggerLoad() {
    if (!_shouldLoad) {
      LazyLoadScope.markLoaded(context, _cacheKey);
      _shimmerController?.stop();
      setState(() => _shouldLoad = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 如果已加载过，直接显示图片
    if (_shouldLoad) {
      return _buildImageWidget(theme);
    }

    // 骨架屏占位符
    Widget placeholder = _buildShimmerPlaceholder(theme);

    // 使用 VisibilityDetector 检测可见性
    return VisibilityDetector(
      key: Key('lazy-image-${widget.heroTag}'),
      onVisibilityChanged: (info) {
        if (!_shouldLoad && info.visibleFraction >= widget.visibilityThreshold) {
          _triggerLoad();
        }
      },
      child: placeholder,
    );
  }

  Widget _buildShimmerPlaceholder(ThemeData theme) {
    final controller = _shimmerController;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    Widget shimmer = AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * controller.value, 0),
              end: Alignment(-0.5 + 2.0 * controller.value, 0),
              colors: [
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );

    if (widget.width != null && widget.height != null && widget.height! > 0) {
      return AspectRatio(
        aspectRatio: widget.width! / widget.height!,
        child: shimmer,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height ?? 200,
      child: shimmer,
    );
  }

  Widget _buildImageWidget(ThemeData theme) {
    Widget imageWidget = GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: widget.heroTag,
        child: Image(
          image: widget.imageProvider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            // 加载中显示进度指示器
            return Container(
              width: widget.width,
              height: widget.height ?? 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: widget.width,
              height: widget.height ?? 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.broken_image,
                color: theme.colorScheme.outline,
                size: 32,
              ),
            );
          },
        ),
      ),
    );

    if (widget.width != null && widget.height != null && widget.height! > 0) {
      return AspectRatio(
        aspectRatio: widget.width! / widget.height!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
