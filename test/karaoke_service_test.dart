import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/karaoke_service.dart';
import 'package:idle_hippo/services/song_catalog_service.dart';

class _FakeDownloader implements AudioDownloadService {
  final Map<String, bool> cached;
  _FakeDownloader(this.cached);

  // ---- Interface stubs ----
  @override
  Dio dio = Dio();

  @override
  BaseDirProvider baseDirProvider = (() async => throw UnimplementedError());

  @override
  DownloadImpl? downloadImpl;

  @override
  Future<String> cachedFilePath(String songId) async => '';

  @override
  Future<bool> isCached(String songId) async => cached[songId] ?? false;

  @override
  Future<void> deleteCache(String songId) async {}

  @override
  Future<void> clearAllCache() async {}

  @override
  Stream<DownloadProgress> download(String songId, String url, {CancelToken? cancelToken}) => const Stream.empty();
}

class _FakeCatalog implements SongCatalogService {
  final List<KtvSong> songs;
  _FakeCatalog(this.songs);

  @override
  AssetLoader assetLoader = (path) => Future.value('');

  @override
  Future<List<KtvSong>> loadSongs() async => songs;
}

void main() {
  group('Step23 KaraokeService', () {
    late GameStateService state;

    setUp(() async {
      state = GameStateService();
      await state.initializeForTest(GameState.initial(1));
    });

    test('案例1：當日未完成結算可多次重試', () async {
      DateTime now() => DateTime(2025, 9, 6, 10);
      final service = KaraokeService(now: now);

      // 初始可玩
      expect(await service.isPlayableToday(), isTrue);
      // 呼叫數次仍可玩（尚未結算）
      expect(await service.isPlayableToday(), isTrue);
      expect(await service.isPlayableToday(), isTrue);
    });

    test('案例2：當日完成結算後返回選單應禁用', () async {
      DateTime now() => DateTime(2025, 9, 6, 10);
      final service = KaraokeService(now: now);

      expect(await service.isPlayableToday(), isTrue);
      await service.markSettledToday();
      expect(await service.isPlayableToday(), isFalse);
    });

    test('案例3：跨日自動重置', () async {
      // 使用 UTC 時間以避免 CI 不同時區導致解析差異：
      // Taipei 2025-09-06 23:50 == UTC 2025-09-06 15:50
      DateTime day1() => DateTime.utc(2025, 9, 6, 15, 50);
      final s1 = KaraokeService(now: day1);
      await s1.markSettledToday();
      expect(await s1.isPlayableToday(), isFalse);

      // 隔天
      // Taipei 2025-09-07 01:00 == UTC 2025-09-06 17:00
      DateTime day2() => DateTime.utc(2025, 9, 6, 17, 0);
      final s2 = KaraokeService(now: day2);
      await s2.ensureKaraokeBlock();
      expect(await s2.isPlayableToday(), isTrue);
    });

    test('案例4：全曲下載按鈕狀態', () async {
      final songs = [
        const KtvSong(
          id: 'a',
          title: 'A',
          image: '',
          music: '',
          lengthSeconds: 10,
          difficulties: [],
        ),
        const KtvSong(
          id: 'b',
          title: 'B',
          image: '',
          music: '',
          lengthSeconds: 10,
          difficulties: [],
        ),
        const KtvSong(
          id: 'c',
          title: 'C',
          image: '',
          music: '',
          lengthSeconds: 10,
          difficulties: [],
        ),
      ];
      final catalog = _FakeCatalog(songs);
      final downloader = _FakeDownloader({'a': true, 'b': true, 'c': false});
      final service = KaraokeService(catalog: catalog, downloader: downloader);

      expect(await service.allSongsDownloaded(), isFalse);
      expect(await service.pendingDownloadIds(), contains('c'));

      downloader.cached['c'] = true;
      expect(await service.allSongsDownloaded(), isTrue);
    });

    test('案例5：試聽功能判斷（僅邏輯）', () async {
      final catalog = _FakeCatalog(const []);
      final downloader = _FakeDownloader({'z': true});
      final service = KaraokeService(catalog: catalog, downloader: downloader);

      // 不可見 → 不試聽
      expect(await service.shouldAutoPreview(false, 'z'), isFalse);
      // 可見 + 已下載 → 試聽
      expect(await service.shouldAutoPreview(true, 'z'), isTrue);
      // 可見 + 未下載 → 不試聽
      expect(await service.shouldAutoPreview(true, 'x'), isFalse);
    });
  });
}
