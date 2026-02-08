import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

/// Widget 截图工具类
class ScreenshotUtils {
  ScreenshotUtils._();

  /// 截取 Widget 为图片字节
  /// [key] - Widget 的 GlobalKey（需要包裹在 RepaintBoundary 中）
  /// [pixelRatio] - 像素比率，默认 2.0（参考 linuxdo-scripts）
  static Future<Uint8List?> captureWidget(GlobalKey key, {double pixelRatio = 2.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[ScreenshotUtils] RenderRepaintBoundary not found');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('[ScreenshotUtils] Failed to get byte data');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[ScreenshotUtils] captureWidget error: $e');
      return null;
    }
  }

  /// 保存图片到相册
  /// 复用 image_viewer_page.dart 的保存逻辑
  static Future<bool> saveToGallery(Uint8List bytes, {String? filename}) async {
    try {
      // 检查权限
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          return false;
        }
      }

      // 生成文件名
      final name = filename ?? 'fluxdo_share_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(bytes, name: '$name.png');
      return true;
    } on GalException catch (e) {
      debugPrint('[ScreenshotUtils] saveToGallery GalException: ${e.type.message}');
      return false;
    } catch (e) {
      debugPrint('[ScreenshotUtils] saveToGallery error: $e');
      return false;
    }
  }

  /// 分享图片
  static Future<void> shareImage(Uint8List bytes, {String? filename}) async {
    try {
      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final name = filename ?? 'fluxdo_share_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${tempDir.path}/$name.png');
      await file.writeAsBytes(bytes);

      // 分享
      final xFile = XFile(file.path, mimeType: 'image/png');
      await SharePlus.instance.share(ShareParams(files: [xFile]));
    } catch (e) {
      debugPrint('[ScreenshotUtils] shareImage error: $e');
      rethrow;
    }
  }
}
