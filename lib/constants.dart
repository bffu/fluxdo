import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 应用常量
class AppConstants {
  /// 是否启用 WebView Cookie 同步（启动时预热 WebView）
  /// 设为 false 时，不使用 WebView 同步，Cookie 由 Dio Set-Cookie 与本地存储维护
  static const bool enableWebViewCookieSync = false;

  /// 动态获取的 User-Agent（与 WebView 一致）
  static String? _userAgent;

  /// 获取 User-Agent（首次调用会从 WebView 获取）
  static Future<String> getUserAgent() async {
    if (_userAgent != null) return _userAgent!;

    try {
      _userAgent = await InAppWebViewController.getDefaultUserAgent();
    } catch (e) {
      // 降级使用平台默认值
      if (Platform.isAndroid) {
        _userAgent = 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      } else if (Platform.isIOS) {
        _userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
      } else if (Platform.isWindows) {
        _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      } else if (Platform.isMacOS) {
        _userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      } else {
        _userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }
    }
    return _userAgent!;
  }

  /// 同步获取 User-Agent（需要先调用 getUserAgent 初始化）
  static String get userAgent => _userAgent ?? 'Mozilla/5.0';

  /// linux.do 域名
  static const String baseUrl = 'https://linux.do';

  /// 请求首页时是否跳过 X-CSRF-Token（用于预热）
  static const bool skipCsrfForHomeRequest = true;
}
