import '../constants.dart';

class UrlHelper {
  /// 修复相对路径 URL
  static String resolveUrl(String url) {
    if (url.startsWith('/')) {
      return '${AppConstants.baseUrl}$url';
    }
    return url;
  }
}
