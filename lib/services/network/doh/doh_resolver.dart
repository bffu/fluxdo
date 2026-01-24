import 'dart:async';
import 'dart:io';

import '../../network_logger.dart';
import 'bootstrap_doh_client.dart';

class DohResolver {
  DohResolver({
    required String serverUrl,
    List<String> bootstrapIps = const [],
    this.enableFallback = true,
    bool preferIPv6 = false,
  })  : _serverUrl = serverUrl,
        _bootstrapIps = bootstrapIps,
        _preferIPv6 = preferIPv6 {
    _initClient();
  }

  String _serverUrl;
  List<String> _bootstrapIps;
  late BootstrapDohClient _client;

  /// 是否启用系统 DNS 回退
  final bool enableFallback;

  /// 是否优先使用 IPv6（用于绕过 SNI 阻断）
  bool _preferIPv6;

  final Map<String, _DohCacheEntryAll> _cacheAll = {};

  void _initClient() {
    _client = BootstrapDohClient(
      serverUrl: _serverUrl,
      bootstrapIps: _bootstrapIps,
      timeout: const Duration(seconds: 5),
      preferIPv6: _preferIPv6,
    );
  }

  void updateServer(String serverUrl, {List<String> bootstrapIps = const []}) {
    if (_serverUrl == serverUrl && _listEquals(_bootstrapIps, bootstrapIps)) {
      return;
    }
    _serverUrl = serverUrl;
    _bootstrapIps = bootstrapIps;
    _cacheAll.clear();
    _client.close();
    _initClient();
  }

  /// 设置是否优先使用 IPv6
  set preferIPv6(bool value) {
    if (_preferIPv6 != value) {
      _preferIPv6 = value;
      _client.preferIPv6 = value; // 同步更新 client
      _cacheAll.clear(); // 清除缓存以使用新的排序策略
    }
  }

  bool get preferIPv6 => _preferIPv6;

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 解析单个地址（兼容旧 API）
  Future<InternetAddress?> resolve(String host) async {
    final addresses = await resolveAll(host);
    return addresses.isNotEmpty ? addresses.first : null;
  }

  /// 解析所有地址
  Future<List<InternetAddress>> resolveAll(String host) async {
    if (host.isEmpty) return [];

    // 检查是否是 IP 地址
    final parsed = InternetAddress.tryParse(host);
    if (parsed != null) return [parsed];

    // 检查缓存
    final cached = _cacheAll[host];
    if (cached != null && !cached.isExpired) {
      return cached.addresses;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await _client.lookupAll(host);
      stopwatch.stop();

      if (addresses.isEmpty) {
        NetworkLogger.logDoh(
          host: host,
          durationMs: stopwatch.elapsedMilliseconds,
          error: 'empty response',
        );
        // DOH 返回空，尝试系统 DNS 回退
        return _fallbackResolveAll(host);
      }

      // 根据设置排序地址（IPv6 优先 / IPv4 优先）
      final sorted = _sortAddresses(addresses);

      NetworkLogger.logDoh(
        host: host,
        durationMs: stopwatch.elapsedMilliseconds,
        resolvedIp: sorted.map((a) => a.address).join(', '),
      );

      // 缓存结果
      _cacheAll[host] = _DohCacheEntryAll(
        addresses: sorted,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      return sorted;
    } catch (e) {
      stopwatch.stop();
      NetworkLogger.logDoh(
        host: host,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
      // DOH 失败，尝试系统 DNS 回退
      return _fallbackResolveAll(host);
    }
  }

  /// 系统 DNS 回退解析（全部）
  Future<List<InternetAddress>> _fallbackResolveAll(String host) async {
    if (!enableFallback) return [];

    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) return [];

      // 根据设置排序地址（IPv6 优先 / IPv4 优先）
      final sorted = _sortAddresses(addresses);

      NetworkLogger.log('[DOH] 系统 DNS 回退成功: $host -> ${sorted.map((a) => a.address).join(', ')}');

      // 缓存结果（回退结果缓存时间短一些）
      _cacheAll[host] = _DohCacheEntryAll(
        addresses: sorted,
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );

      return sorted;
    } catch (e) {
      NetworkLogger.log('[DOH] 系统 DNS 回退也失败: $host | $e');
      return [];
    }
  }

  Future<int?> testLatency(String host) async {
    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await _client.lookupAll(host);
      if (addresses.isEmpty) return null;
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  /// 根据 preferIPv6 设置排序地址
  List<InternetAddress> _sortAddresses(List<InternetAddress> addresses) {
    if (_preferIPv6) {
      // IPv6 优先，有助于绕过 SNI 阻断
      return <InternetAddress>[
        ...addresses.where((a) => a.type == InternetAddressType.IPv6),
        ...addresses.where((a) => a.type != InternetAddressType.IPv6),
      ];
    } else {
      // IPv4 优先（默认）
      return <InternetAddress>[
        ...addresses.where((a) => a.type == InternetAddressType.IPv4),
        ...addresses.where((a) => a.type != InternetAddressType.IPv4),
      ];
    }
  }

  void dispose() {
    _client.close();
  }
}

class _DohCacheEntryAll {
  _DohCacheEntryAll({required this.addresses, required this.expiresAt});

  final List<InternetAddress> addresses;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
