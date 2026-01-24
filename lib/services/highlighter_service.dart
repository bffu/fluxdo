import 'package:flutter/material.dart';
import 'package:flutter_highlighting/flutter_highlighting.dart';
import 'package:flutter_highlighting/themes/github.dart';
import 'package:flutter_highlighting/themes/dracula.dart';

/// 单例服务，用于管理语法高亮器。
/// 使用 flutter_highlighting 包（highlight.js Dart 移植版）。
class HighlighterService {
  static HighlighterService? _instance;

  // flutter_highlighting 支持的语言白名单
  static const _supportedLanguages = {
    'bash', 'c', 'cpp', 'csharp', 'css', 'dart', 'diff', 'go', 'graphql',
    'html', 'java', 'javascript', 'json', 'kotlin', 'lua', 'makefile',
    'markdown', 'objectivec', 'perl', 'php', 'plaintext', 'python', 'ruby',
    'rust', 'scala', 'shell', 'sql', 'swift', 'typescript', 'xml', 'yaml',
  };

  HighlighterService._();
  
  static HighlighterService get instance {
    _instance ??= HighlighterService._();
    return _instance!;
  }
  
  /// 初始化（当前为空操作，HighlightView 内部处理语言注册）
  void initialize() {
    // HighlightView 会自动处理语言注册，无需手动初始化
  }
  
  /// 获取代码高亮 Widget
  /// [code] 代码内容
  /// [language] 语言ID（可选，为 null 时使用 plaintext）
  /// [isDark] 是否使用深色主题
  Widget buildHighlightView(
    String code, {
    String? language,
    bool isDark = false,
    Color? backgroundColor,
    EdgeInsets padding = const EdgeInsets.all(12),
    TextStyle? textStyle,
  }) {
    var theme = isDark ? draculaTheme : githubTheme;
    if (backgroundColor != null) {
      theme = Map<String, TextStyle>.from(theme);
      theme['root'] = (theme['root'] ?? const TextStyle()).copyWith(
        backgroundColor: backgroundColor,
      );
    }

    final normalizedLang = _normalizeLanguage(language, code);
    final safeLang = _supportedLanguages.contains(normalizedLang) ? normalizedLang : 'plaintext';
    final style = textStyle ?? const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
    );

    return HighlightView(
      code,
      languageId: safeLang,
      theme: theme,
      padding: padding,
      textStyle: style,
    );
  }
  
  /// 语言名称标准化
  String _normalizeLanguage(String? lang, [String? code]) {
    if (lang == null || lang.isEmpty || lang == 'auto') {
      // 尝试自动检测语言
      if (code != null && code.isNotEmpty) {
        final detected = _detectLanguage(code);
        if (detected != null) {
          return detected;
        }
      }
      return 'plaintext'; // highlight.js 使用 plaintext 作为默认
    }
    
    final normalized = lang.toLowerCase();
    
    switch (normalized) {
      case 'js':
        return 'javascript';
      case 'ts':
        return 'typescript';
      case 'py':
        return 'python';
      case 'rb':
        return 'ruby';
      case 'yml':
        return 'yaml';
      case 'sh':
        return 'bash';
      default:
        return normalized;
    }
  }
  
  /// 简单的语言自动检测
  String? _detectLanguage(String code) {
    final trimmed = code.trim();
    
    // JSON: 以 { 或 [ 开头，且是有效的 JSON 结构
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      // 简单检查是否像 JSON（包含 : 和引号）
      if (trimmed.contains(':') && (trimmed.contains('"') || trimmed.contains("'"))) {
        return 'json';
      }
    }
    
    // XML/HTML: 以 < 开头
    if (trimmed.startsWith('<') && trimmed.contains('>')) {
      if (trimmed.contains('<!DOCTYPE html') || trimmed.contains('<html')) {
        return 'html';
      }
      if (trimmed.startsWith('<?xml')) {
        return 'xml';
      }
    }
    
    // Bash: shebang 或常见命令模式
    if (trimmed.startsWith('#!') && trimmed.contains('bash')) {
      return 'bash';
    }
    if (trimmed.startsWith(r'$') || RegExp(r'^(sudo|apt|yum|npm|yarn|pip|git|docker|kubectl)\s').hasMatch(trimmed)) {
      return 'bash';
    }
    
    // Python: def, class, import, from...import
    if (RegExp(r'^(def |class |import |from \w+ import |if __name__)').hasMatch(trimmed)) {
      return 'python';
    }
    
    // JavaScript/TypeScript: function, const, let, var, =>
    if (RegExp(r'^(function |const |let |var |export |import .* from )').hasMatch(trimmed)) {
      return 'javascript';
    }
    
    // Dart: void main, class, import 'package:
    if (trimmed.contains("import 'package:") || trimmed.contains('import "package:')) {
      return 'dart';
    }
    
    // YAML: key: value 结构，且没有 { }
    if (RegExp(r'^\w+:\s*(\n|$)').hasMatch(trimmed) && !trimmed.contains('{')) {
      return 'yaml';
    }
    
    // SQL: SELECT, INSERT, UPDATE, CREATE
    if (RegExp(r'^(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\s', caseSensitive: false).hasMatch(trimmed)) {
      return 'sql';
    }
    
    return null; // 无法检测
  }
}
