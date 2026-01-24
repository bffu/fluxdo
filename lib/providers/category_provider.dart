import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../models/topic.dart';
import 'core_providers.dart';

class ActiveCategorySlugsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void add(String slug) {
    if (slug.isEmpty) return;
    if (state.contains(slug)) return;
    state = {...state, slug};
  }

  void reset() {
    state = <String>{};
  }
}

final activeCategorySlugsProvider =
    NotifierProvider<ActiveCategorySlugsNotifier, Set<String>>(
        () => ActiveCategorySlugsNotifier());

/// 分类列表 Provider
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.watch(discourseServiceProvider);
  return service.getCategories();
});

/// 分类 Map Provider (ID -> Category)
/// 用于快速查找
final categoryMapProvider = Provider<AsyncValue<Map<int, Category>>>((ref) {
  final categoriesAsync = ref.watch(categoriesProvider);
  return categoriesAsync.whenData((categories) {
    return {for (var c in categories) c.id: c};
  });
});

/// 热门标签列表 Provider
final tagsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(discourseServiceProvider);
  return service.getTags();
});

/// 站点是否支持标签功能
final canTagTopicsProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(discourseServiceProvider);
  return service.canTagTopics();
});

/// 分类下的话题列表 Provider
final categoryTopicsProvider = FutureProvider.family<TopicListResponse, String>((ref, slug) async {
  final service = ref.watch(discourseServiceProvider);
  return service.getCategoryTopics(slug);
});
