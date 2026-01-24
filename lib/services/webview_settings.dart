import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// WebView 配置工具类
/// 区分 Headless（后台同步）和 Visible（用户可见页面）两种场景
class WebViewSettings {
  WebViewSettings._();

  /// Headless WebView 配置（后台同步用，轻量）
  /// 用于 CookieSyncService、WebViewHttpAdapter、CF 自动验证等
  static InAppWebViewSettings get headless => InAppWebViewSettings(
    javaScriptEnabled: true,
    sharedCookiesEnabled: true,

    // 性能优化 - 不加载不必要的资源
    blockNetworkImage: true,
    mediaPlaybackRequiresUserGesture: true,
    allowsInlineMediaPlayback: false,

    // 缓存优化
    cacheEnabled: true,
    cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,

    // 禁用不需要的回调以减少开销
    useShouldOverrideUrlLoading: false,
    useShouldInterceptRequest: false,
    useOnLoadResource: false,
    useOnDownloadStart: false,

    // 其他优化
    transparentBackground: true,
    disableContextMenu: true,
    supportZoom: false,

    // 安全相关
    thirdPartyCookiesEnabled: true,
  );

  /// 可见 WebView 配置（登录页、CF 手动验证等，完整功能）
  /// 用于 WebViewLoginPage、CF 手动验证页面等
  static InAppWebViewSettings get visible => InAppWebViewSettings(
    javaScriptEnabled: true,
    sharedCookiesEnabled: true,
    domStorageEnabled: true,

    // 保持完整功能
    blockNetworkImage: false,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,

    // 缓存
    cacheEnabled: true,

    // 保持默认回调（可能需要）
    useShouldOverrideUrlLoading: false,

    // 安全相关
    thirdPartyCookiesEnabled: true,
  );
}
