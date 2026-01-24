import 'package:flutter/material.dart';

/// 话题列表骨架屏
class TopicListSkeleton extends StatelessWidget {
  const TopicListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      itemBuilder: (context, index) => const _TopicCardSkeleton(),
    );
  }
}

/// 单个话题卡片的骨架屏
class _TopicCardSkeleton extends StatefulWidget {
  const _TopicCardSkeleton();

  @override
  State<_TopicCardSkeleton> createState() => _TopicCardSkeletonState();
}

class _TopicCardSkeletonState extends State<_TopicCardSkeleton>
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(
                        controller: _shimmerController,
                        width: double.infinity,
                        height: 20,
                        theme: theme,
                      ),
                      const SizedBox(height: 6),
                      _ShimmerBox(
                        controller: _shimmerController,
                        width: 200,
                        height: 20,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 分类和标签行
            Row(
              children: [
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 24,
                  height: 24,
                  borderRadius: 6,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 80,
                  height: 16,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 60,
                  height: 16,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 底部信息行
            Row(
              children: [
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 24,
                  height: 24,
                  borderRadius: 12,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 60,
                  height: 14,
                  theme: theme,
                ),
                const Spacer(),
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 40,
                  height: 14,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _ShimmerBox(
                  controller: _shimmerController,
                  width: 40,
                  height: 14,
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 带 shimmer 动画的占位框（与 LazyImage 风格一致）
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
