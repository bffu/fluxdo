import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants.dart';
import '../widgets/common/loading_spinner.dart';
import 'network/cookie/cookie_jar_service.dart';
import 'network/cookie/cookie_sync_service.dart';
import 'local_notification_service.dart'; // 用于获取全局 navigatorKey

/// CF 验证服务
/// 处理 Cloudflare Turnstile 验证（仅手动模式）
class CfChallengeService {
  static final CfChallengeService _instance = CfChallengeService._internal();
  factory CfChallengeService() => _instance;
  CfChallengeService._internal();

  bool _isVerifying = false;
  final _verifyCompleter = <Completer<bool>>[];
  BuildContext? _context;
  
  /// 冷却机制：验证失败后进入冷却期
  DateTime? _cooldownUntil;
  static const _cooldownDuration = Duration(seconds: 30);
  
  /// 检查是否在冷却期
  bool get isInCooldown {
    if (_cooldownUntil == null) return false;
    if (DateTime.now().isAfter(_cooldownUntil!)) {
      _cooldownUntil = null;
      return false;
    }
    return true;
  }
  
  /// 重置冷却期（验证成功后调用）
  void resetCooldown() => _cooldownUntil = null;
  
  /// 手动启动冷却期
  void startCooldown() => _cooldownUntil = DateTime.now().add(_cooldownDuration);

  void setContext(BuildContext context) {
    _context = context;
  }

  /// 检测是否是 CF 验证页面
  static bool isCfChallenge(dynamic responseData) {
    if (responseData == null) return false;
    final str = responseData.toString();
    return str.contains('Just a moment') ||
           str.contains('cf_chl_opt') ||
           str.contains('challenge-platform');
  }

  /// 显示手动验证页面
  /// 返回值：true=验证成功, false=验证失败, null=冷却期内暂不可用或无 context
  Future<bool?> showManualVerify([BuildContext? context]) async {
    // 检查冷却期
    if (isInCooldown) {
      debugPrint('[CfChallenge] In cooldown, skipping manual verify');
      return null;
    }
    
    // 尝试获取 context：传入的 > 已设置的 > 全局 navigatorKey
    BuildContext? ctx = context ?? _context;
    if (ctx == null) {
      // 使用全局 navigatorKey 作为备用
      final navState = navigatorKey.currentState;
      if (navState != null && navState.context.mounted) {
        ctx = navState.context;
        debugPrint('[CfChallenge] Using global navigatorKey context');
      }
    }
    
    if (ctx == null) {
      debugPrint('[CfChallenge] No context available for manual verify (context not set and navigatorKey not ready)');
      // 返回 null 而不是 false，让调用方知道这是"无法验证"而非"验证失败"
      return null;
    }

    if (_isVerifying) {
      // 已经在验证中，等待结果
      final completer = Completer<bool>();
      _verifyCompleter.add(completer);
      return completer.future;
    }

    _isVerifying = true;

    // 打开 WebView 前先同步 Cookie 到 WebView
    await CookieJarService().syncToWebView();

    final result = await Navigator.of(ctx).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CfChallengePage(),
        fullscreenDialog: true,
      ),
    );

    _isVerifying = false;

    // 通知所有等待者
    for (final c in _verifyCompleter) {
      if (!c.isCompleted) c.complete(result ?? false);
    }
    _verifyCompleter.clear();

    // 验证成功后从 WebView 同步 Cookie 回 CookieJar
    if (result == true) {
      resetCooldown(); // 重置冷却期
      await CookieJarService().syncFromWebView();
    } else {
      // 验证失败，启动冷却期
      _cooldownUntil = DateTime.now().add(_cooldownDuration);
      debugPrint('[CfChallenge] Verification failed, cooldown until $_cooldownUntil');
    }

    return result ?? false;
  }
}

/// CF 验证页面
class CfChallengePage extends StatefulWidget {
  const CfChallengePage({super.key});

  @override
  State<CfChallengePage> createState() => _CfChallengePageState();
}

class _CfChallengePageState extends State<CfChallengePage> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  Timer? _checkTimer;
  String? _initialCfClearance;
  bool _navigatedAfterClearance = false;
  bool _hasPopped = false; // 防止重复 pop
  int _checkCount = 0;
  static const _maxCheckCount = 60;

  bool _isChallengeUrl(WebUri? url) {
    final value = url?.toString() ?? '';
    return value.contains('/challenge') || value.contains('__cf_chl');
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('安全验证'),
            if (_checkCount > 0)
              Text(
                '验证中... ${_checkCount}s',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: '帮助',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri('${AppConstants.baseUrl}/challenge')),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    userAgent: AppConstants.userAgent,
                    // useShouldOverrideUrlLoading: true, // 不要设置这个，除非实现了 shouldOverrideUrlLoading 回调，否则会阻塞页面加载
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStart: (_, __) => setState(() {
                    _isLoading = true;
                    _progress = 0;
                  }),
                  onProgressChanged: (controller, progress) {
                    setState(() => _progress = progress / 100);
                  },
                  onLoadStop: (controller, url) {
                    setState(() => _isLoading = false);
                    _startVerifyCheck(controller);
                    if (!_isChallengeUrl(url) && !_hasPopped) {
                      _hasPopped = true;
                      Navigator.of(context).pop(true);
                    }
                  },
                  onLoadError: (controller, url, code, message) {
                    setState(() => _isLoading = false);
                    _showError('加载失败: $message');
                  },
                ),
                if (_checkCount > _maxCheckCount - 10 && _checkCount <= _maxCheckCount)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '验证时间较长，还剩 ${_maxCheckCount - _checkCount} 秒',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 启动定时检查验证状态（非阻塞）
  void _startVerifyCheck(InAppWebViewController controller) {
    _checkTimer?.cancel();
    _checkCount = 0;

    Future<String?> getCfClearance() async {
      final cookies = await CookieManager.instance().getCookies(url: WebUri(AppConstants.baseUrl));
      for (final cookie in cookies) {
        if (cookie.name == 'cf_clearance') return cookie.value;
      }
      return null;
    }

    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _checkCount++;
      setState(() {}); // 更新计数显示

      if (_checkCount > _maxCheckCount) {
        timer.cancel();
        if (mounted && !_hasPopped) {
          _hasPopped = true;
          _showError('验证超时，请重试');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop(false);
          }
        }
        return;
      }

      try {
        _initialCfClearance ??= await getCfClearance();
        final html = await controller.evaluateJavascript(source: 'document.body.innerHTML');
        final isChallenge = CfChallengeService.isCfChallenge(html);
        debugPrint('[CfChallenge] tick#$_checkCount isChallenge=$isChallenge');

        if (html != null && !isChallenge) {
          timer.cancel();
          if (mounted && !_hasPopped) {
            _hasPopped = true;
            Navigator.of(context).pop(true);
          }
        }

        final currentCfClearance = await getCfClearance();
        final clearanceChanged = currentCfClearance != null &&
            currentCfClearance.isNotEmpty &&
            (_initialCfClearance == null || currentCfClearance != _initialCfClearance);

        if (clearanceChanged) {
          debugPrint('[CfChallenge] clearance updated');
          if (!_navigatedAfterClearance) {
            _navigatedAfterClearance = true;
            debugPrint('[CfChallenge] navigating to baseUrl');
            await controller.loadUrl(
              urlRequest: URLRequest(url: WebUri(AppConstants.baseUrl)),
            );
            return;
          }
          timer.cancel();
          if (mounted && !_hasPopped) {
            _hasPopped = true;
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        debugPrint('[CfChallenge] Check error: $e');
      }
    });
  }

  void _refresh() {
    _checkTimer?.cancel();
    _checkCount = 0;
    _initialCfClearance = null;
    _navigatedAfterClearance = false;
    setState(() {
      _isLoading = true;
      _progress = 0;
    });
    _controller?.reload();
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('验证帮助'),
        content: const Text(
          '这是 Cloudflare 安全验证页面。\n\n'
          '请完成页面上的验证挑战（如勾选框或滑块）。\n\n'
          '验证成功后会自动关闭此页面。\n\n'
          '如果长时间无法完成，可以尝试：\n'
          '• 点击刷新按钮重新加载\n'
          '• 检查网络连接\n'
          '• 关闭后稍后再试',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
