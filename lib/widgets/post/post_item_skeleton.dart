import 'package:flutter/material.dart';

/// 帖子骨架屏
class PostItemSkeleton extends StatefulWidget {
  const PostItemSkeleton({super.key});

  @override
  State<PostItemSkeleton> createState() => _PostItemSkeletonState();
}

class _PostItemSkeletonState extends State<PostItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像和用户信息行
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              _ShimmerBox(
                controller: _shimmerController,
                width: 40,
                height: 40,
                borderRadius: 20,
                theme: theme,
              ),
              const SizedBox(width: 12),
              // 用户名和时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      controller: _shimmerController,
                      width: 120,
                      height: 16,
                      theme: theme,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBox(
                      controller: _shimmerController,
                      width: 80,
                      height: 12,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 内容区域（多行）
          _ShimmerBox(
            controller: _shimmerController,
            width: double.infinity,
            height: 16,
            theme: theme,
          ),
          const SizedBox(height: 8),
          _ShimmerBox(
            controller: _shimmerController,
            width: double.infinity,
            height: 16,
            theme: theme,
          ),
          const SizedBox(height: 8),
          _ShimmerBox(
            controller: _shimmerController,
            width: 200,
            height: 16,
            theme: theme,
          ),
          const SizedBox(height: 16),
          // 操作按钮行
          Row(
            children: [
              _ShimmerBox(
                controller: _shimmerController,
                width: 60,
                height: 32,
                borderRadius: 16,
                theme: theme,
              ),
              const SizedBox(width: 12),
              _ShimmerBox(
                controller: _shimmerController,
                width: 60,
                height: 32,
                borderRadius: 16,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 带 shimmer 动画的占位框
class _ShimmerBox extends StatelessWidget {
  final AnimationController controller;
  final double width;
  final double height;
  final double borderRadius;
  final ThemeData theme;

  const _ShimmerBox({
    required this.controller,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
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
}

/// 单个骨架屏项的估算高度
const double kPostItemSkeletonHeight = 200.0;

/// 根据可用高度计算骨架屏数量
int calculateSkeletonCount(double availableHeight, {int minCount = 3}) {
  final count = (availableHeight / kPostItemSkeletonHeight).ceil();
  return count.clamp(minCount, 20);
}

/// 话题详情 Header 骨架屏
class TopicDetailHeaderSkeleton extends StatefulWidget {
  const TopicDetailHeaderSkeleton({super.key});

  @override
  State<TopicDetailHeaderSkeleton> createState() => _TopicDetailHeaderSkeletonState();
}

class _TopicDetailHeaderSkeletonState extends State<TopicDetailHeaderSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题（两行）
          _ShimmerBox(
            controller: _shimmerController,
            width: double.infinity,
            height: 24,
            theme: theme,
          ),
          const SizedBox(height: 8),
          _ShimmerBox(
            controller: _shimmerController,
            width: 200,
            height: 24,
            theme: theme,
          ),
          const SizedBox(height: 12),
          // 分类和标签
          Row(
            children: [
              _ShimmerBox(
                controller: _shimmerController,
                width: 80,
                height: 24,
                borderRadius: 4,
                theme: theme,
              ),
              const SizedBox(width: 8),
              _ShimmerBox(
                controller: _shimmerController,
                width: 60,
                height: 24,
                borderRadius: 4,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 元数据行（回复、浏览、时间）
          Row(
            children: [
              _ShimmerBox(
                controller: _shimmerController,
                width: 60,
                height: 14,
                theme: theme,
              ),
              const SizedBox(width: 16),
              _ShimmerBox(
                controller: _shimmerController,
                width: 60,
                height: 14,
                theme: theme,
              ),
              const SizedBox(width: 16),
              _ShimmerBox(
                controller: _shimmerController,
                width: 80,
                height: 14,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Header 骨架屏的估算高度
const double kTopicDetailHeaderSkeletonHeight = 150.0;

/// 帖子列表骨架屏（用于初始加载）
class PostListSkeleton extends StatelessWidget {
  final int? itemCount;
  final bool withHeader; // 是否显示 Header 骨架屏

  const PostListSkeleton({
    super.key,
    this.itemCount, // 如果不指定，则根据屏幕高度动态计算
    this.withHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // 减去 AppBar 和状态栏高度
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    var availableHeight = screenHeight - appBarHeight;
    
    // 如果有 header，减去 header 高度
    if (withHeader) {
      availableHeight -= kTopicDetailHeaderSkeletonHeight;
    }
    
    final count = itemCount ?? calculateSkeletonCount(availableHeight);

    return ListView.builder(
      itemCount: count + (withHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (withHeader && index == 0) {
          return const TopicDetailHeaderSkeleton();
        }
        return const PostItemSkeleton();
      },
    );
  }
}
