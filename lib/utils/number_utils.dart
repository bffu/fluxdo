/// 数值工具类 - 统一处理数值格式化
class NumberUtils {
  NumberUtils._();

  /// 格式化数量为简洁形式
  /// 10000+ 显示为 1.0w
  /// 1000+ 显示为 1.0k
  static String formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
