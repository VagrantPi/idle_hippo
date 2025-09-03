import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:idle_hippo/services/song_catalog_service.dart';

void main() {
  group('歌曲清單解析 - SongCatalogService', () {
    test('正常解析一首歌（標題/時長/難度星數）', () async {
      final svc = SongCatalogService();
      svc.assetLoader = (_) async => '{"songs":[{"id":"EchoesOfTheVoid","title":"Echoes Of The Void","image":"assets/images/musicGame/EchoesOfTheVoid.jpg","music":"https://example.com/EchoesOfTheVoid.mp3","length_seconds":120,"difficulties":[{"level":"easy","key_count":3},{"level":"hard","key_count":5}]}]}';

      final list = await svc.loadSongs();
      expect(list.length, 1);
      final song = list.first;
      expect(song.id, 'EchoesOfTheVoid');
      expect(song.title, 'Echoes Of The Void');
      expect(song.lengthSeconds, 120);
      expect(song.difficulties.length, 2);
      expect(song.difficulties.first.level, 'easy');
      expect(song.difficulties.first.keyCount, 3);
      expect(song.difficulties.last.level, 'hard');
      expect(song.difficulties.last.keyCount, 5);
    });

    test('資料異常或空清單時回傳空陣列', () async {
      final svc = SongCatalogService();
      // 缺少 songs 欄位
      svc.assetLoader = (_) async => '{"foo":1}';
      final list1 = await svc.loadSongs();
      expect(list1, isEmpty);

      // songs 不是陣列
      svc.assetLoader = (_) async => '{"songs":1}';
      final list2 = await svc.loadSongs();
      expect(list2, isEmpty);

      // 單筆缺欄位（id/music 缺）被略過，回傳空
      svc.assetLoader = (_) async => '{"songs":[{"title":"X"}] }';
      final list3 = await svc.loadSongs();
      expect(list3, isEmpty);
    });

    test('KtvCollectionParser 解析多筆 songs', () {
      const jsonStr = '{"songs":[{"id":"A","title":"A","image":"i","music":"u","length_seconds":60,"difficulties":[]},{"id":"B","title":"B","image":"i","music":"u","length_seconds":90,"difficulties":[{"level":"easy","key_count":2}]}]}';
      final parsed = KtvCollectionParser.parse(jsonStr);
      expect(parsed.length, 2);
      expect(parsed[0].id, 'A');
      expect(parsed[1].id, 'B');
      expect(parsed[1].difficulties.first.keyCount, 2);
    });
  });
}
