import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_favorite_topic_archive.dart';

class LocalFavoriteArchiveService {
  static const _archiveDirName = 'local_favorite_archives';

  Future<Directory> _ensureArchiveDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${baseDir.path}${Platform.pathSeparator}$_archiveDirName');
    if (!archiveDir.existsSync()) {
      await archiveDir.create(recursive: true);
    }
    return archiveDir;
  }

  Future<File> _archiveFile(int topicId) async {
    final dir = await _ensureArchiveDir();
    return File('${dir.path}${Platform.pathSeparator}$topicId.json');
  }

  Future<void> saveArchive(LocalFavoriteTopicArchive archive) async {
    try {
      final file = await _archiveFile(archive.topicId);
      final content = jsonEncode(archive.toJson());
      await file.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('[LocalFavoriteArchive] saveArchive failed: ${archive.topicId}, $e');
    }
  }

  Future<LocalFavoriteTopicArchive?> loadArchive(int topicId) async {
    try {
      final file = await _archiveFile(topicId);
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;
      return LocalFavoriteTopicArchive.fromJson(decoded);
    } catch (e) {
      debugPrint('[LocalFavoriteArchive] loadArchive failed: $topicId, $e');
      return null;
    }
  }

  Future<bool> hasArchive(int topicId) async {
    final file = await _archiveFile(topicId);
    return file.existsSync();
  }

  Future<void> deleteArchive(int topicId) async {
    try {
      final file = await _archiveFile(topicId);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[LocalFavoriteArchive] deleteArchive failed: $topicId, $e');
    }
  }

  Future<void> deleteArchives(Iterable<int> topicIds) async {
    for (final topicId in topicIds) {
      await deleteArchive(topicId);
    }
  }
}
