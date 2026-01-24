import 'dart:async';
import 'discourse_service.dart';

/// 阅读时间上报成功后的回调
/// [topicId] 话题 ID
/// [postNumbers] 已上报的帖子编号集合
/// [highestSeen] 最高已读帖子编号
typedef OnTimingsSent = void Function(int topicId, Set<int> postNumbers, int highestSeen);

/// 帖子浏览时间追踪服务
class ScreenTrack {
  static const _flushInterval = Duration(seconds: 60);
  static const _tickInterval = Duration(milliseconds: 1500);
  static const _pauseUnlessScrolled = Duration(minutes: 3);
  static const _maxTrackingTime = Duration(minutes: 6);

  final DiscourseService _service;
  final OnTimingsSent? onTimingsSent;

  int? _topicId;
  Timer? _tickTimer;
  DateTime? _lastTick;
  DateTime? _lastScrolled;
  Duration _lastFlush = Duration.zero;
  int _topicTime = 0;

  final Map<int, int> _timings = {};
  final Map<int, int> _totalTimings = {};
  Set<int> _onscreen = {};
  bool _inProgress = false;

  ScreenTrack(this._service, {this.onTimingsSent});

  void start(int topicId) {
    if (_topicId != null && _topicId != topicId) {
      _flush();
    }
    _reset();
    _topicId = topicId;
    _tickTimer ??= Timer.periodic(_tickInterval, (_) => _tick());
  }

  void stop() {
    if (_topicId == null) return;
    _flush();
    _reset();
    _topicId = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void setOnscreen(Set<int> postNumbers) {
    _onscreen = postNumbers;
  }

  void scrolled() {
    _lastScrolled = DateTime.now();
  }

  void _reset() {
    final now = DateTime.now();
    _lastTick = now;
    _lastScrolled = now;
    _lastFlush = Duration.zero;
    _timings.clear();
    _totalTimings.clear();
    _topicTime = 0;
    _onscreen = {};
    _inProgress = false;
  }

  void _tick() {
    final now = DateTime.now();

    // 长时间未滚动则暂停追踪
    final sinceScrolled = now.difference(_lastScrolled ?? now);
    if (sinceScrolled > _pauseUnlessScrolled) return;

    final diff = now.difference(_lastTick ?? now).inMilliseconds;
    _lastFlush += Duration(milliseconds: diff);
    _lastTick = now;

    // 检查是否需要立即上报（有新的未上报帖子）
    final rush = _timings.entries.any((e) =>
      e.value > 0 && !_totalTimings.containsKey(e.key));

    // print('[ScreenTrack] tick: diff=${diff}ms, lastFlush=${_lastFlush.inSeconds}s, rush=$rush, inProgress=$_inProgress');

    if (!_inProgress && (_lastFlush > _flushInterval || rush)) {
      print('[ScreenTrack] Triggering flush. LastFlush: ${_lastFlush.inSeconds}s, Rush: $rush');
      _flush();
    }

    // 累计时间（不检查生命周期，简化处理）
    _topicTime += diff;
    for (final postNumber in _onscreen) {
      _timings[postNumber] = (_timings[postNumber] ?? 0) + diff;
    }
  }

  void _flush() {
    final topicId = _topicId;
    if (topicId == null) return;

    final newTimings = <int, int>{};
    for (final entry in _timings.entries) {
      final postNumber = entry.key;
      final time = entry.value;
      final totalTime = _totalTimings[postNumber] ?? 0;

      if (time > 0 && totalTime < _maxTrackingTime.inMilliseconds) {
        _totalTimings[postNumber] = totalTime + time;
        newTimings[postNumber] = time;
      }
      _timings[postNumber] = 0;
    }

    if (newTimings.isNotEmpty) {
      print('[ScreenTrack] Flushing timings for topic $topicId: $newTimings');
      _sendTimings(topicId, _topicTime, newTimings);
      _topicTime = 0;
    } else {
      // print('[ScreenTrack] Nothing to flush');
    }
    _lastFlush = Duration.zero;
  }

  Future<void> _sendTimings(int topicId, int topicTime, Map<int, int> timings) async {
    if (_inProgress) return;
    if (!_service.isAuthenticated) return;
    _inProgress = true;
    try {
      print('[ScreenTrack] Sending timings to server...');
      await _service.topicsTimings(
        topicId: topicId,
        topicTime: topicTime,
        timings: timings,
      );
      print('[ScreenTrack] Timings sent successfully.');
      
      // 上报成功后调用回调，同步本地状态
      if (timings.isNotEmpty && onTimingsSent != null) {
        final highestSeen = timings.keys.reduce((a, b) => a > b ? a : b);
        print('[ScreenTrack] Calling onTimingsSent. HighestSeen: $highestSeen');
        onTimingsSent!(topicId, timings.keys.toSet(), highestSeen);
      }
    } catch (e) {
      print('[ScreenTrack] Failed to send timings: $e');
    } finally {
      _inProgress = false;
    }
  }
}
