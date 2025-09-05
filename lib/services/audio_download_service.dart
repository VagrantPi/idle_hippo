import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadProgress {
  final int received;
  final int? total;
  final double? percent; // 0..100（若 total 不可得，為 null）

  const DownloadProgress({required this.received, this.total, this.percent});
}

typedef BaseDirProvider = Future<Directory> Function();
typedef DownloadImpl =
    Future<Response<dynamic>> Function(
      String url,
      String savePath, {
      ProgressCallback? onReceiveProgress,
      CancelToken? cancelToken,
    });

class AudioDownloadService {
  static final AudioDownloadService _instance =
      AudioDownloadService._internal();
  factory AudioDownloadService() => _instance;
  AudioDownloadService._internal();

  // 可注入以便測試
  Dio dio = Dio();
  BaseDirProvider baseDirProvider = getApplicationDocumentsDirectory;
  DownloadImpl? downloadImpl;

  /// 取得歌曲最終快取檔案完整路徑（{songId}.mp3）。
  Future<String> cachedFilePath(String songId) async {
    return _getSongPath(songId);
  }

  Future<String> _getSongPath(String songId) async {
    final dir = await baseDirProvider();
    final audioDir = Directory(p.join(dir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return p.join(audioDir.path, '$songId.mp3');
  }

  Future<String> _getTempPath(String songId) async {
    final dir = await baseDirProvider();
    final audioDir = Directory(p.join(dir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return p.join(audioDir.path, '.$songId.mp3.part');
  }

  Future<String> _getOkMarkerPath(String songId) async {
    final dir = await baseDirProvider();
    final audioDir = Directory(p.join(dir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return p.join(audioDir.path, '.${songId}.ok');
  }

  Future<bool> isCached(String songId) async {
    final path = await _getSongPath(songId);
    final okPath = await _getOkMarkerPath(songId);
    final f = File(path);
    final ok = File(okPath);
    final exists = f.existsSync() && (await f.length()) > 0;
    final valid = exists && ok.existsSync();
    return valid;
  }

  Future<void> deleteCache(String songId) async {
    final path = await _getSongPath(songId);
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
    final okPath = await _getOkMarkerPath(songId);
    final okFile = File(okPath);
    if (await okFile.exists()) {
      await okFile.delete();
    }
  }

  /// 清除所有下載的快取檔案
  Future<void> clearAllCache() async {
    try {
      final dir = await baseDirProvider();
      final audioDir = Directory(p.join(dir.path, 'audio'));

      if (await audioDir.exists()) {
        // 刪除目錄中的所有檔案
        await for (var entity in audioDir.list(recursive: true)) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // 忽略錯誤，繼續執行
      print('Error clearing audio cache: $e');
    }
  }

  /// 下載檔案。回傳進度 Stream（0..100%，若 total 不可得則 percent 為 null）。
  /// 成功完成時將 .part 重新命名為最終檔名。
  /// 任何失敗或取消都會刪除半成品。
  Future<void> _doDownload(
    String songId,
    String url,
    StreamController<DownloadProgress> controller,
    CancelToken? cancelToken,
  ) async {
    final tempPath = await _getTempPath(songId);
    final finalPath = await _getSongPath(songId);

    // 清理殘留 temp
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    void progress(int received, int total) {
      if (!controller.isClosed) {
        if (total > 0) {
          final percent = (received / total) * 100.0;
          controller.add(
            DownloadProgress(
              received: received,
              total: total,
              percent: percent,
            ),
          );
        } else {
          controller.add(
            DownloadProgress(received: received, total: null, percent: null),
          );
        }
      }
    }

    try {
      final impl = downloadImpl;
      if (impl != null) {
        await impl(
          url,
          tempPath,
          onReceiveProgress: progress,
          cancelToken: cancelToken,
        );
      } else {
        await dio.download(
          url,
          tempPath,
          onReceiveProgress: progress,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
          ),
        );
      }

      // 下載完成，rename 至最終檔名
      final f = File(tempPath);
      if (!await f.exists()) {
        throw Exception('temp file missing');
      }
      // 若目標已存在，先刪除（共用單一音檔）
      final target = File(finalPath);
      if (await target.exists()) {
        await target.delete();
      }
      await f.rename(finalPath);
      // 建立完成標記檔，代表此歌曲檔案已完整下載
      final okPath = await _getOkMarkerPath(songId);
      await File(okPath).writeAsString('ok');
      // 發送完成事件（100%）
      if (!controller.isClosed) {
        controller.add(DownloadProgress(received: 1, total: 1, percent: 100));
      }
    } catch (e) {
      // 取消或失敗，刪除 temp
      try {
        final f = File(tempPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}

      if (!controller.isClosed) {
        controller.addError(e);
      }
    } finally {
      await controller.close();
    }
  }

  Stream<DownloadProgress> download(
    String songId,
    String url, {
    CancelToken? cancelToken,
  }) {
    final controller = StreamController<DownloadProgress>();
    final impl = downloadImpl;
    if (impl != null) {
      _doDownload(songId, url, controller, cancelToken);
    } else {
      Future.microtask(() => _doDownload(songId, url, controller, cancelToken));
    }

    return controller.stream;
  }
}
