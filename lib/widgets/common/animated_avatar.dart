import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../services/discourse_cache_manager.dart';

/// 支持 GIF 动画的头像组件
/// 手动管理 ImageStream 并使用 Ticker 驱动多帧图片动画
class AnimatedAvatar extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BoxBorder? border;

  const AnimatedAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.fallbackText,
    this.backgroundColor,
    this.foregroundColor,
    this.border,
  });

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar> with SingleTickerProviderStateMixin {
  static final DiscourseCacheManager _cacheManager = DiscourseCacheManager();

  ui.Image? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;

  // GIF 动画相关
  ui.Codec? _codec;
  Ticker? _ticker;
  Duration _frameDuration = Duration.zero;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(AnimatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _disposeAnimation();
      _loadImage();
    }
  }

  @override
  void dispose() {
    _disposeAnimation();
    super.dispose();
  }

  void _disposeAnimation() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _codec?.dispose();
    _codec = null;
    _currentFrame?.dispose();
    _currentFrame = null;
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _currentFrame = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 使用缓存管理器获取文件
      final file = await _cacheManager.getSingleFile(widget.imageUrl!);
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Empty image data');
      }

      // 解码图片
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecFromBuffer(buffer);

      if (!mounted) {
        codec.dispose();
        return;
      }

      _codec = codec;

      // 获取第一帧
      final frameInfo = await codec.getNextFrame();

      if (!mounted) {
        frameInfo.image.dispose();
        return;
      }

      setState(() {
        _currentFrame = frameInfo.image;
        _frameDuration = frameInfo.duration;
        _isLoading = false;
        _hasError = false;
      });

      // 如果是多帧图片（GIF），启动动画
      if (codec.frameCount > 1) {
        _startAnimation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _startAnimation() {
    _ticker?.dispose();
    _ticker = createTicker(_onTick);
    _elapsed = Duration.zero;
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (_codec == null || _frameDuration == Duration.zero) return;

    final newElapsed = elapsed;
    if (newElapsed - _elapsed >= _frameDuration) {
      _elapsed = newElapsed;
      _loadNextFrame();
    }
  }

  Future<void> _loadNextFrame() async {
    if (_codec == null || !mounted) return;

    try {
      final frameInfo = await _codec!.getNextFrame();
      if (mounted) {
        setState(() {
          _currentFrame?.dispose();
          _currentFrame = frameInfo.image;
          _frameDuration = frameInfo.duration;
        });
      } else {
        frameInfo.image.dispose();
      }
    } catch (e) {
      // 忽略帧加载错误
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.primaryContainer;
    final fgColor = widget.foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    Widget child;
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      child = _buildFallback(fgColor);
    } else if (_isLoading) {
      child = _buildLoading(fgColor);
    } else if (_hasError || _currentFrame == null) {
      child = _buildFallback(fgColor);
    } else {
      child = RawImage(
        image: _currentFrame,
        fit: BoxFit.cover,
        width: widget.radius * 2,
        height: widget.radius * 2,
      );
    }

    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: widget.border,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildLoading(Color fgColor) {
    return Center(
      child: SizedBox(
        width: widget.radius * 0.6,
        height: widget.radius * 0.6,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: fgColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildFallback(Color fgColor) {
    if (widget.fallbackText != null && widget.fallbackText!.isNotEmpty) {
      return Center(
        child: Text(
          widget.fallbackText![0].toUpperCase(),
          style: TextStyle(
            color: fgColor,
            fontWeight: FontWeight.bold,
            fontSize: widget.radius * 0.8,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person,
        size: widget.radius,
        color: fgColor,
      ),
    );
  }
}
