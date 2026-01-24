import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/discourse_service.dart';

/// Discourse 服务 Provider
final discourseServiceProvider = Provider((ref) => DiscourseService());

/// 认证错误 Provider（监听登录失效事件）
final authErrorProvider = StreamProvider<String>((ref) {
  final service = ref.watch(discourseServiceProvider);
  return service.authErrorStream;
});

/// 认证状态变化 Provider（登录/退出）
final authStateProvider = StreamProvider<void>((ref) {
  final service = ref.watch(discourseServiceProvider);
  return service.authStateStream;
});

/// 当前用户 Provider
/// 使用 FutureProvider 实现自动加载和刷新
final currentUserProvider = FutureProvider<User?>((ref) async {
  final service = ref.watch(discourseServiceProvider);
  // 只需要获取一次用户名，后续通过 getUser 获取详情
  // 这里直接复用 service.getCurrentUser()
  return service.getCurrentUser();
});

/// 用户统计数据 Provider
final userSummaryProvider = FutureProvider<UserSummary?>((ref) async {
  final service = ref.watch(discourseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  return service.getUserSummary(user.username);
});
