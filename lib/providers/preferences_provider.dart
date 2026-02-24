// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';

class AppPreferences {
  final bool autoPanguSpacing;
  final bool anonymousShare;
  final bool longPressPreview;
  final bool openExternalLinksInAppBrowser;
  final bool threadedCommentMode;
  final List<String> blockedCommentKeywords;
  /// 内容字体缩放比例，范围 0.8 ~ 1.4，默认 1.0
  final double contentFontScale;
  /// 分享图片主题索引
  final int shareImageThemeIndex;

  const AppPreferences({
    required this.autoPanguSpacing,
    required this.anonymousShare,
    required this.longPressPreview,
    required this.openExternalLinksInAppBrowser,
    required this.threadedCommentMode,
    required this.blockedCommentKeywords,
    required this.contentFontScale,
    required this.shareImageThemeIndex,
  });

  AppPreferences copyWith({
    bool? autoPanguSpacing,
    bool? anonymousShare,
    bool? longPressPreview,
    bool? openExternalLinksInAppBrowser,
    bool? threadedCommentMode,
    List<String>? blockedCommentKeywords,
    double? contentFontScale,
    int? shareImageThemeIndex,
  }) {
    return AppPreferences(
      autoPanguSpacing: autoPanguSpacing ?? this.autoPanguSpacing,
      anonymousShare: anonymousShare ?? this.anonymousShare,
      longPressPreview: longPressPreview ?? this.longPressPreview,
      openExternalLinksInAppBrowser:
          openExternalLinksInAppBrowser ?? this.openExternalLinksInAppBrowser,
      threadedCommentMode: threadedCommentMode ?? this.threadedCommentMode,
      blockedCommentKeywords: blockedCommentKeywords ?? this.blockedCommentKeywords,
      contentFontScale: contentFontScale ?? this.contentFontScale,
      shareImageThemeIndex: shareImageThemeIndex ?? this.shareImageThemeIndex,
    );
  }
}

class PreferencesNotifier extends StateNotifier<AppPreferences> {
  static const String _autoPanguSpacingKey = 'pref_auto_pangu_spacing';
  static const String _anonymousShareKey = 'pref_anonymous_share';
  static const String _longPressPreviewKey = 'pref_long_press_preview';
  static const String _openExternalLinksInAppBrowserKey =
      'pref_open_external_links_in_app_browser';
  static const String _threadedCommentModeKey = 'pref_threaded_comment_mode';
  static const String _blockedCommentKeywordsKey = 'pref_blocked_comment_keywords';
  static const String _contentFontScaleKey = 'pref_content_font_scale';
  static const String _shareImageThemeIndexKey = 'pref_share_image_theme_index';

  static List<String> _normalizeKeywords(List<String> keywords) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final keyword in keywords) {
      final value = keyword.trim().toLowerCase();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      normalized.add(value);
    }
    return normalized;
  }

  PreferencesNotifier(this._prefs)
      : super(
          AppPreferences(
            autoPanguSpacing: _prefs.getBool(_autoPanguSpacingKey) ?? false,
            anonymousShare: _prefs.getBool(_anonymousShareKey) ?? false,
            longPressPreview: _prefs.getBool(_longPressPreviewKey) ?? true,
            openExternalLinksInAppBrowser:
                _prefs.getBool(_openExternalLinksInAppBrowserKey) ?? false,
            threadedCommentMode: _prefs.getBool(_threadedCommentModeKey) ?? true,
            blockedCommentKeywords: _normalizeKeywords(
              _prefs.getStringList(_blockedCommentKeywordsKey) ?? const [],
            ),
            contentFontScale: _prefs.getDouble(_contentFontScaleKey) ?? 1.0,
            shareImageThemeIndex: _prefs.getInt(_shareImageThemeIndexKey) ?? 0,
          ),
        );

  final SharedPreferences _prefs;

  Future<void> setAutoPanguSpacing(bool enabled) async {
    state = state.copyWith(autoPanguSpacing: enabled);
    await _prefs.setBool(_autoPanguSpacingKey, enabled);
  }

  Future<void> setAnonymousShare(bool enabled) async {
    state = state.copyWith(anonymousShare: enabled);
    await _prefs.setBool(_anonymousShareKey, enabled);
  }

  Future<void> setLongPressPreview(bool enabled) async {
    state = state.copyWith(longPressPreview: enabled);
    await _prefs.setBool(_longPressPreviewKey, enabled);
  }

  Future<void> setOpenExternalLinksInAppBrowser(bool enabled) async {
    state = state.copyWith(openExternalLinksInAppBrowser: enabled);
    await _prefs.setBool(_openExternalLinksInAppBrowserKey, enabled);
  }

  Future<void> setThreadedCommentMode(bool enabled) async {
    state = state.copyWith(threadedCommentMode: enabled);
    await _prefs.setBool(_threadedCommentModeKey, enabled);
  }

  Future<void> setBlockedCommentKeywords(List<String> keywords) async {
    final normalized = _normalizeKeywords(keywords);
    state = state.copyWith(blockedCommentKeywords: normalized);
    await _prefs.setStringList(_blockedCommentKeywordsKey, normalized);
  }

  Future<void> setContentFontScale(double scale) async {
    // 限制范围在 0.8 ~ 1.4
    final clampedScale = scale.clamp(0.8, 1.4);
    state = state.copyWith(contentFontScale: clampedScale);
    await _prefs.setDouble(_contentFontScaleKey, clampedScale);
  }

  Future<void> setShareImageThemeIndex(int index) async {
    state = state.copyWith(shareImageThemeIndex: index);
    await _prefs.setInt(_shareImageThemeIndexKey, index);
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesNotifier(prefs);
});
