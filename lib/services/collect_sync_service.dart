import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/image_cache_service.dart';
import 'package:dio/dio.dart';

typedef BaseDirProvider = Future<Directory> Function();
typedef NowProvider = DateTime Function();
typedef SleepFn = Future<void> Function(Duration d);

class CollectHttpResponse {
  final int statusCode; // 200 | 304 | other
  final String? body;
  final String? etag;
  const CollectHttpResponse({required this.statusCode, this.body, this.etag});
}

typedef HttpFetch =
    Future<CollectHttpResponse> Function(String url, {String? ifNoneMatch});
typedef ImageExists = Future<bool> Function(String id);
typedef ImageDownload = Future<String> Function(String id, String url);

class CollectUpdateResult {
  final String status; // 'updated' | 'not_modified' | 'failed'
  final int attempts;
  final String? message;
  const CollectUpdateResult(this.status, this.attempts, {this.message});
}

/// Step24: SWR + ETag 更新 assets/audio/collect.json 至 appdata://collect.json
class CollectSyncService {
  final GameStateService _state;
  final String remoteUrl; // collect.json URL
  final String? versionUrl; // version.json URL（可選）
  BaseDirProvider baseDirProvider;
  HttpFetch httpFetch;
  NowProvider now;
  SleepFn sleep;
  ImageExists imageExists;
  ImageDownload imageDownload;
  Dio dio;

  CollectSyncService({
    GameStateService? state,
    required this.remoteUrl,
    this.versionUrl,
    BaseDirProvider? baseDirProvider,
    HttpFetch? httpFetch,
    NowProvider? now,
    SleepFn? sleep,
    ImageExists? imageExists,
    ImageDownload? imageDownload,
  }) : _state = state ?? GameStateService(),
       baseDirProvider = baseDirProvider ?? getApplicationDocumentsDirectory,
       dio = Dio(),
       httpFetch =
           httpFetch ??
           ((url, {String? ifNoneMatch}) async {
             final d = Dio();
             try {
               final resp = await d.get(
                 url,
                 options: Options(
                   followRedirects: true,
                   validateStatus: (s) => true,
                   headers: {
                     if (ifNoneMatch != null && ifNoneMatch.isNotEmpty)
                       'If-None-Match': ifNoneMatch,
                   },
                 ),
               );
               final sc = resp.statusCode ?? 0;
               final etag = resp.headers.value('etag');
               if (sc == 200) {
                 final data = resp.data;
                 final body = data is String
                     ? data
                     : (data is List<int>
                           ? utf8.decode(data)
                           : jsonEncode(data));
                 return CollectHttpResponse(
                   statusCode: sc,
                   body: body,
                   etag: etag,
                 );
               }
               return CollectHttpResponse(statusCode: sc, etag: etag);
             } catch (_) {
               // 視為錯誤，由外層重試
               rethrow;
             }
           }),
       now = now ?? DateTime.now,
       sleep = sleep ?? ((d) => Future.delayed(d)),
       imageExists = imageExists ?? ImageCacheService().isCached,
       imageDownload = imageDownload ?? ImageCacheService().download;

  Future<String> _localPath() async {
    final dir = await baseDirProvider();
    return p.join(dir.path, 'collect.json');
  }

  /// 嘗試拉取更新並原子覆寫本地 collect.json。
  /// - 304: 不變更狀態
  /// - 200: 通過驗證後寫入檔案並更新 etag/version
  /// - 其他/異常: 最多 3 次退避 1s/2s/3s
  Future<CollectUpdateResult> checkAndUpdate() async {
    if (remoteUrl.isEmpty) {
      return const CollectUpdateResult('failed', 0, message: 'no_remote_url');
    }

    final s = _state.currentState;
    final k0 = s.karaoke ?? KaraokeState.initial();
    var attempts = 0;
    final backoffs = [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 3),
    ];

    // 可選：先讀 version.json，若版本未提升則直接 not_modified
    int? targetVersion;
    if ((versionUrl ?? '').isNotEmpty) {
      try {
        final verResp = await httpFetch(versionUrl!);
        if (verResp.statusCode == 200 && (verResp.body?.isNotEmpty ?? false)) {
          final root = jsonDecode(verResp.body!);
          if (root is Map && root['version'] != null) {
            final v = root['version'];
            if (v is num) targetVersion = v.toInt();
            if (v is String) targetVersion = int.tryParse(v);
          }
        }
      } catch (_) {
        // 忽略錯誤，退回 ETag 流程
      }
      if (targetVersion != null && targetVersion <= k0.collectVersion) {
        return const CollectUpdateResult('not_modified', 0);
      }
    }

    while (attempts < 3) {
      attempts++;
      try {
        final resp = await httpFetch(
          remoteUrl,
          ifNoneMatch: targetVersion == null ? k0.collectEtag : null,
        );
        if (resp.statusCode == 304) {
          return CollectUpdateResult('not_modified', attempts);
        }
        if (resp.statusCode == 200 && (resp.body?.isNotEmpty ?? false)) {
          // 驗證 JSON 結構
          final parsed = KtvCollectionParser.parse(resp.body!);
          if (parsed.isEmpty) {
            // 不覆寫舊檔
            return CollectUpdateResult(
              'failed',
              attempts,
              message: 'invalid_json',
            );
          }
          // 嘗試讀取 version 欄位
          int? newVersion;
          try {
            final root = jsonDecode(resp.body!);
            if (root is Map<String, dynamic> && root['version'] != null) {
              final v = root['version'];
              if (v is num) newVersion = v.toInt();
              if (v is String) newVersion = int.tryParse(v);
            }
          } catch (_) {}
          // 原子寫入
          final path = await _localPath();
          final file = File(path);
          final tmp = File('$path.tmp');
          if (!await file.parent.exists()) {
            await file.parent.create(recursive: true);
          }
          await tmp.writeAsString(resp.body!, flush: true);
          if (await file.exists()) {
            await file.delete();
          }
          await tmp.rename(path);

          // 更新狀態（version.json > JSON 內 version > +1）
          final resolvedVersion =
              targetVersion ?? newVersion ?? (k0.collectVersion + 1);
          final k1 = k0.copyWith(
            collectVersion: resolvedVersion,
            collectEtag: resp.etag ?? k0.collectEtag,
            collectUpdatedAt: now().toUtc().millisecondsSinceEpoch,
            collectPath: 'appdata://collect.json',
          );
          await _state.updateGameState(s.copyWith(karaoke: k1));

          // 下載缺少的封面圖片（僅針對不存在者）
          for (final song in parsed) {
            try {
              if (await imageExists(song.id)) continue;
              final imgUrl = song.image;
              if (imgUrl.isEmpty) continue;
              if (!imgUrl.startsWith('http')) continue;
              await imageDownload(song.id, imgUrl);
            } catch (_) {
              // 單筆錯誤忽略，保持主流程穩定
            }
          }
          return CollectUpdateResult('updated', attempts);
        }
        // 其他狀態碼 => 當成失敗
        if (attempts < 3) await sleep(backoffs[attempts - 1]);
      } catch (_) {
        if (attempts < 3) await sleep(backoffs[attempts - 1]);
      }
    }
    return CollectUpdateResult('failed', attempts, message: 'max_retries');
  }
}
