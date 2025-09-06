import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/collect_sync_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/song_catalog_service.dart';

void main() {
  group('Step24 collect.json SWR/ETag', () {
    late Directory tmp;
    late GameStateService state;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('hippo_swr_test');
      state = GameStateService();
      await state.initializeForTest(GameState.initial(1));
    });

    tearDown(() async {
      try {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('ETag 304 -> 不更新版本與檔案', () async {
      final init = state.currentState.copyWith(
        karaoke: const KaraokeState(
          lastPlayDate: '',
          playedToday: false,
          collectVersion: 2,
          collectEtag: 'abc',
          collectUpdatedAt: 0,
          collectPath: 'appdata://collect.json',
        ),
      );
      await state.updateGameState(init);

      int calls = 0;
      final svc = CollectSyncService(
        state: state,
        remoteUrl: 'https://example.com/collect.json',
        baseDirProvider: () async => tmp,
        httpFetch: (url, {String? ifNoneMatch}) async {
          calls++;
          expect(ifNoneMatch, 'abc');
          return const CollectHttpResponse(statusCode: 304);
        },
        sleep: (_) async {},
      );

      final result = await svc.checkAndUpdate();
      expect(result.status, 'not_modified');
      expect(calls, 1);
      final after = state.currentState.karaoke!;
      expect(after.collectVersion, 2);
      expect(after.collectEtag, 'abc');
      final f = File('${tmp.path}/collect.json');
      expect(await f.exists(), isFalse);
    });

    test('ETag 200 -> 原子覆寫並版本+1', () async {
      final init = state.currentState.copyWith(
        karaoke: const KaraokeState(
          lastPlayDate: '',
          playedToday: false,
          collectVersion: 1,
          collectEtag: 'abc',
          collectUpdatedAt: 0,
          collectPath: 'appdata://collect.json',
        ),
      );
      await state.updateGameState(init);

      final body = '{"songs":[{"id":"s1","title":"T","image":"i","music":"u","length_seconds":60,"difficulties":[]}]}';
      int calls = 0;
      final svc = CollectSyncService(
        state: state,
        remoteUrl: 'https://example.com/collect.json',
        baseDirProvider: () async => tmp,
        httpFetch: (url, {String? ifNoneMatch}) async {
          calls++;
          return CollectHttpResponse(statusCode: 200, body: body, etag: 'def');
        },
        now: () => DateTime.utc(2025, 1, 2, 3, 4, 5),
        sleep: (_) async {},
        imageExists: (_) async => true, // 不觸發圖片下載
      );

      final result = await svc.checkAndUpdate();
      expect(result.status, 'updated');
      expect(calls, 1);
      final f = File('${tmp.path}/collect.json');
      expect(await f.exists(), isTrue);
      final text = await f.readAsString();
      expect(text, body);
      final after = state.currentState.karaoke!;
      expect(after.collectVersion, 2);
      expect(after.collectEtag, 'def');
      expect(after.collectUpdatedAt, greaterThan(0));
    });

    test('200 並含 version 與新歌曲 → collectVersion=version 且下載缺少的封面', () async {
      final init = state.currentState.copyWith(
        karaoke: const KaraokeState(
          lastPlayDate: '',
          playedToday: false,
          collectVersion: 1,
          collectEtag: 'abc',
          collectUpdatedAt: 0,
          collectPath: 'appdata://collect.json',
        ),
      );
      await state.updateGameState(init);

      // 包含 version 與 image URL
      final body = '{"version":3,"songs":[{"id":"new1","title":"N","image":"https://example.com/new1.png","music":"u","length_seconds":10,"difficulties":[]}]}';
      int downloads = 0;
      final svc = CollectSyncService(
        state: state,
        remoteUrl: 'https://example.com/collect.json',
        baseDirProvider: () async => tmp,
        httpFetch: (url, {String? ifNoneMatch}) async =>
            CollectHttpResponse(statusCode: 200, body: body, etag: 'e3'),
        sleep: (_) async {},
        imageExists: (id) async => false,
        imageDownload: (id, url) async {
          downloads++;
          // simulate write file
          final f = File('${tmp.path}/images/$id.png');
          await f.parent.create(recursive: true);
          await f.writeAsString('ok');
          return f.path;
        },
      );

      final result = await svc.checkAndUpdate();
      expect(result.status, 'updated');
      expect(downloads, 1);
      expect(state.currentState.karaoke!.collectVersion, 3);
    });

    test('連續三次失敗 -> 保留舊檔與狀態', () async {
      final init = state.currentState.copyWith(
        karaoke: const KaraokeState(
          lastPlayDate: '',
          playedToday: false,
          collectVersion: 7,
          collectEtag: 'zzz',
          collectUpdatedAt: 123,
          collectPath: 'appdata://collect.json',
        ),
      );
      await state.updateGameState(init);

      int calls = 0;
      final svc = CollectSyncService(
        state: state,
        remoteUrl: 'https://example.com/collect.json',
        baseDirProvider: () async => tmp,
        httpFetch: (url, {String? ifNoneMatch}) async {
          calls++;
          throw Exception('net err');
        },
        sleep: (_) async {},
      );

      final result = await svc.checkAndUpdate();
      expect(result.status, 'failed');
      expect(calls, 3);
      final after = state.currentState.karaoke!;
      expect(after.collectVersion, 7);
      expect(after.collectEtag, 'zzz');
      final f = File('${tmp.path}/collect.json');
      expect(await f.exists(), isFalse);
    });

    test('SongCatalogService 優先載入本地 appdata 檔案', () async {
      final jsonBody = '{"songs":[{"id":"x","title":"X","image":"i","music":"u","length_seconds":30,"difficulties":[]}]}';
      final file = File('${tmp.path}/collect.json');
      await file.writeAsString(jsonBody);

      // 打上 karaoke.collectPath 讓服務啟用本地模式
      await state.updateGameState(state.currentState.copyWith(
        karaoke: const KaraokeState(
          lastPlayDate: '',
          playedToday: false,
          collectVersion: 1,
          collectEtag: 'e',
          collectUpdatedAt: 1,
          collectPath: 'appdata://collect.json',
        ),
      ));

      final svc = SongCatalogService();
      svc.baseDirProvider = () async => tmp;
      // assetLoader 不應被呼叫；即便被呼叫也回傳錯誤以確保路徑生效
      svc.assetLoader = (_) async => throw Exception('should not load asset');

      final songs = await svc.loadSongs();
      expect(songs.length, 1);
      expect(songs.first.id, 'x');
    });

    test('透過 version.json 判斷需要更新，下載 collect 並同步 collectVersion', () async {
      await state.updateGameState(state.currentState.copyWith(
        karaoke: const KaraokeState(
          lastPlayDate: '',
          playedToday: false,
          collectVersion: 1,
          collectEtag: '',
          collectUpdatedAt: 0,
          collectPath: 'appdata://collect.json',
        ),
      ));

      int calls = 0;
      final svc = CollectSyncService(
        state: state,
        remoteUrl: 'collect',
        versionUrl: 'version',
        baseDirProvider: () async => tmp,
        httpFetch: (url, {String? ifNoneMatch}) async {
          calls++;
          if (url == 'version') {
            return const CollectHttpResponse(
              statusCode: 200,
              body: '{"version":2}',
            );
          }
          if (url == 'collect') {
            return const CollectHttpResponse(
              statusCode: 200,
              body:
                  '{"version":2,"songs":[{"id":"v2","title":"V2","image":"https://example.com/v2.png","music":"u","length_seconds":10,"difficulties":[]}]}',
              etag: 'etag2',
            );
          }
          return const CollectHttpResponse(statusCode: 404);
        },
        imageExists: (_) async => true,
        sleep: (_) async {},
      );

      final result = await svc.checkAndUpdate();
      expect(result.status, 'updated');
      expect(state.currentState.karaoke!.collectVersion, 2);
      expect(calls, greaterThanOrEqualTo(2));
    });
  });
}
