/// SVG 处理工具类
///
/// 提供 SVG 内容清理和修复功能，使 flutter_svg 能正确渲染复杂 SVG
/// 
/// 支持：
/// - 移除 SMIL 动画元素
/// - 移除 CSS 动画（style 标签）
/// - 提取 CSS 类样式并内联到元素
/// - 处理嵌套 SVG 标签
/// - 修复 text 元素的 scale 变换
class SvgUtils {
  SvgUtils._();

  /// 清理 SVG 内容，使其能被 flutter_svg 正确渲染
  /// 
  /// [svg] 原始 SVG 内容
  /// 返回清理后的 SVG 字符串
  static String sanitize(String svg) {
    String result = svg;
    
    // 1. 提取 CSS 类中的 fill 和 stroke 颜色，内联到使用该类的元素
    result = _inlineBasicStyles(result);
    
    // 2. 移除 flutter_svg 不支持的元素
    result = _removeUnsupportedElements(result);
    
    // 3. 移除 SMIL 动画标签
    result = _removeAnimations(result);
    
    // 4. 移除 XML 声明和注释
    result = _removeXmlDeclarationAndComments(result);
    
    // 5. 处理嵌套的 SVG 标签
    result = _flattenNestedSvg(result);
    
    // 6. 修复 text 元素的 scale 变换
    result = _fixTextScale(result);
    
    return result;
  }

  /// 从 CSS 类定义中提取 fill 和 stroke，内联到使用该类的元素
  static String _inlineBasicStyles(String content) {
    // 匹配 CSS 类定义
    final classPattern = RegExp(
      r'\.([a-zA-Z_-][a-zA-Z0-9_-]*)\s*\{([^}]*)\}',
      dotAll: true,
    );
    
    // 提取每个类的 fill 和 stroke
    final classStyles = <String, Map<String, String>>{};
    for (final match in classPattern.allMatches(content)) {
      final className = match.group(1)!;
      final cssContent = match.group(2)!;
      
      final styles = <String, String>{};
      
      // 提取 fill
      final fillMatch = RegExp(r'fill\s*:\s*([^;]+);').firstMatch(cssContent);
      if (fillMatch != null) {
        final value = fillMatch.group(1)!.trim();
        if (value != 'none') {
          styles['fill'] = value;
        }
      }
      
      // 提取 stroke
      final strokeMatch = RegExp(r'(?<!-)stroke\s*:\s*([^;]+);').firstMatch(cssContent);
      if (strokeMatch != null) {
        styles['stroke'] = strokeMatch.group(1)!.trim();
      }
      
      // 提取 stroke-width
      final strokeWidthMatch = RegExp(r'stroke-width\s*:\s*([^;]+);').firstMatch(cssContent);
      if (strokeWidthMatch != null) {
        styles['stroke-width'] = strokeWidthMatch.group(1)!.trim();
      }
      
      if (styles.isNotEmpty) {
        classStyles[className] = styles;
      }
    }
    
    // 将样式内联到使用该类的元素
    String result = content;
    for (final entry in classStyles.entries) {
      final className = entry.key;
      final styles = entry.value;
      
      // 匹配使用该类的元素
      // 注意：需要正确处理自闭合标签 <path ... /> 和普通标签 <path ...>
      final elementPattern = RegExp(
        r'(<[a-zA-Z]+\s+)([^>]*class\s*=\s*"' + RegExp.escape(className) + r'"[^>]*?)(\s*/\s*>|>)',
        dotAll: true,
      );
      
      result = result.replaceAllMapped(elementPattern, (match) {
        final tagStart = match.group(1)!;
        String attrs = match.group(2)!;
        final close = match.group(3)!;
        
        // 添加内联样式属性
        for (final style in styles.entries) {
          // 只添加元素上没有的属性
          if (!RegExp('${style.key}\\s*=').hasMatch(attrs)) {
            attrs = '$attrs ${style.key}="${style.value}"';
          }
        }
        
        return '$tagStart$attrs$close';
      });
    }
    
    return result;
  }

  /// 移除 flutter_svg 不支持的元素
  static String _removeUnsupportedElements(String content) {
    String result = content;
    
    // 移除 <style>...</style>
    result = result.replaceAll(
      RegExp(r'<style\b[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      '',
    );
    
    // 移除 <filter>...</filter>
    result = result.replaceAll(
      RegExp(r'<filter\b[^>]*>.*?</filter>', caseSensitive: false, dotAll: true),
      '',
    );
    
    // 移除 filter 属性引用
    result = result.replaceAll(
      RegExp(r'\s*filter\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'filter\s*:\s*[^;]+;', caseSensitive: false),
      '',
    );
    
    // 移除空的或只有注释的 <defs> 标签
    result = result.replaceAll(
      RegExp(r'<defs\b[^>]*>[\s\n]*(?:<!--.*?-->[\s\n]*)*</defs>', caseSensitive: false, dotAll: true),
      '',
    );
    
    return result;
  }

  /// 移除 SMIL 动画标签
  static String _removeAnimations(String content) {
    final smilPattern = RegExp(
      r'<(animate|animateTransform|animateMotion|animateColor|set)\b[^>]*(?:/>|>.*?</\1>)',
      caseSensitive: false,
      dotAll: true,
    );
    return content.replaceAll(smilPattern, '');
  }

  /// 移除 XML 声明和 HTML 注释
  static String _removeXmlDeclarationAndComments(String content) {
    String result = content;
    
    // 移除 XML 声明
    result = result.replaceAll(
      RegExp(r'<\?xml[^?]*\?>', caseSensitive: false),
      '',
    );
    
    // 移除 HTML 注释
    result = result.replaceAll(
      RegExp(r'<!--.*?-->', dotAll: true),
      '',
    );
    
    return result;
  }

  /// 处理嵌套的 SVG 标签 - 提取内层 SVG 的内容合并到外层
  static String _flattenNestedSvg(String content) {
    String result = content;
    
    final nestedSvgPattern = RegExp(
      r'(<svg\b[^>]*>)\s*<svg\b[^>]*>(.*?)</svg>\s*(</svg>)',
      caseSensitive: false,
      dotAll: true,
    );
    
    while (nestedSvgPattern.hasMatch(result)) {
      result = result.replaceFirstMapped(nestedSvgPattern, (match) {
        final outerStart = match.group(1)!;
        final innerContent = match.group(2)!;
        final outerEnd = match.group(3)!;
        return '$outerStart$innerContent$outerEnd';
      });
    }
    
    return result;
  }

  /// 修复 SVG 中 text 元素的 scale 变换问题
  static String _fixTextScale(String svg) {
    final fontSizeMatch = RegExp(r'font-size="(\d+)"').firstMatch(svg);
    if (fontSizeMatch == null) return svg;

    final fontSize = int.tryParse(fontSizeMatch.group(1)!) ?? 0;
    if (fontSize <= 20) return svg;

    final scaleMatch = RegExp(r'transform="scale(\.(\d+))"').firstMatch(svg);
    if (scaleMatch == null) return svg;

    final scaleValue = double.tryParse('0.${scaleMatch.group(1)}') ?? 1.0;
    final newFontSize = (fontSize * scaleValue).round();

    String result = svg;
    result = result.replaceAll('font-size="$fontSize"', 'font-size="$newFontSize"');
    result = result.replaceAll(RegExp(r' transform="scale\(\.\d+\)"'), '');

    result = result.replaceAllMapped(
      RegExp(r'<text([^>]*) x="(\d+)"([^>]*) y="(\d+)"'),
      (m) {
        final x = ((int.tryParse(m.group(2)!) ?? 0) * scaleValue).round();
        final y = ((int.tryParse(m.group(4)!) ?? 0) * scaleValue).round();
        return '<text${m.group(1)} x="$x"${m.group(3)} y="$y"';
      },
    );

    return result;
  }
}
