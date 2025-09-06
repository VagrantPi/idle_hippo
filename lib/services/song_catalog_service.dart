import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:idle_hippo/models/ktv_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:idle_hippo/services/game_state_service.dart';

typedef AssetLoader = Future<String> Function(String path);
typedef BaseDirProvider = Future<Directory> Function();
typedef FileReader = Future<String> Function(String path);

class SongCatalogService {
  static final SongCatalogService _instance = SongCatalogService._internal();
  factory SongCatalogService() => _instance;
  SongCatalogService._internal();

  // 允許測試注入
  AssetLoader assetLoader = (path) => rootBundle.loadString(path);
  BaseDirProvider baseDirProvider = getApplicationDocumentsDirectory;
  FileReader fileReader = ((path) async => File(path).readAsString());
  GameStateService gameStateService = GameStateService();

  Future<List<KtvSong>> loadSongs() async {
    try {
      // 優先讀取本地 appdata://collect.json（若存在），否則回退 assets
      String? jsonString;
      final k = gameStateService.currentState.karaoke;
      if (k != null && k.collectPath.startsWith('appdata://')) {
        try {
          final dir = await baseDirProvider();
          final filePath = p.join(dir.path, 'collect.json');
          final f = File(filePath);
          if (await f.exists()) {
            jsonString = await fileReader(filePath);
          }
        } catch (_) {
          // 讀取本地失敗則回退 assets
        }
      }
      jsonString ??= await assetLoader('assets/audio/collect.json');
      final songs = KtvCollectionParser.parse(jsonString);
      // 嘗試將 image 指向本地快取（若存在）
      final dir = await baseDirProvider();
      final imgDir = Directory(p.join(dir.path, 'images'));
      final mapped = <KtvSong>[];
      for (final s in songs) {
        String imgPath = s.image;
        if (await imgDir.exists()) {
          for (final ext in const ['png', 'jpg', 'jpeg', 'webp']) {
            final f = File(p.join(imgDir.path, '${s.id}.$ext'));
            if (await f.exists()) {
              imgPath = f.path; // 使用本地檔案路徑
              break;
            }
          }
        }
        mapped.add(KtvSong(
          id: s.id,
          title: s.title,
          image: imgPath,
          music: s.music,
          lengthSeconds: s.lengthSeconds,
          difficulties: s.difficulties,
        ));
      }
      return mapped;
    } catch (_) {
      // 異常時回傳空清單，交由 UI 顯示空態/重試
      return const [];
    }
  }
}
