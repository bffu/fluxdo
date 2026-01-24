import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

import '../doh/network_settings_service.dart';
import 'network_http_adapter.dart';
import 'webview_http_adapter.dart';

/// 根据平台和代理状态配置适配器
///
/// | 代理状态       | 平台        | 适配器              |
/// |----------------|-------------|---------------------|
/// | 禁用           | Windows     | WebViewHttpAdapter  |
/// | 禁用           | 其他平台    | NativeAdapter       |
/// | DoH/ECH 启用   | Windows     | WebViewHttpAdapter  |
/// | DoH/ECH 启用   | 其他平台    | NetworkHttpAdapter  |
///
/// 设计思路：
/// - NativeAdapter 性能更好（使用 Cronet/cupertino_http），但不支持应用层代理
/// - NetworkHttpAdapter 支持通过 Rust 代理处理 DoH/ECH
/// - Windows 必须使用 WebView 适配器来绕过 CF 验证
void configurePlatformAdapter(Dio dio) {
  final settings = NetworkSettingsService.instance;

  if (Platform.isWindows) {
    // Windows: 始终使用 WebView 适配器
    final adapter = WebViewHttpAdapter();
    dio.httpClientAdapter = adapter;
    adapter.initialize().then((_) {
      debugPrint('[DIO] Using WebViewHttpAdapter on Windows');
    }).catchError((e) {
      debugPrint('[DIO] WebViewHttpAdapter init failed: $e');
    });
  } else if (settings.current.dohEnabled) {
    // DOH 启用: 使用 NetworkHttpAdapter（通过 Rust 代理处理 DOH + ECH）
    dio.httpClientAdapter = NetworkHttpAdapter(settings);
    debugPrint(
        '[DIO] Using NetworkHttpAdapter with DOH proxy on ${Platform.operatingSystem}');
  } else {
    // 代理禁用: 使用 NativeAdapter（性能更好）
    // Android 使用 Cronet, iOS/macOS 使用 cupertino_http
    dio.httpClientAdapter = NativeAdapter();
    debugPrint('[DIO] Using NativeAdapter on ${Platform.operatingSystem}');
  }
}

/// 根据当前 DoH 设置重新配置适配器
/// 由于 Dio 实例创建后适配器可以动态切换，当 DoH 设置改变时调用此方法
void reconfigurePlatformAdapter(Dio dio) {
  // 先关闭旧适配器
  dio.httpClientAdapter.close();
  // 重新配置
  configurePlatformAdapter(dio);
}
