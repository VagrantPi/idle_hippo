import 'package:flutter/services.dart' show rootBundle;
import 'package:idle_hippo/models/ktv_models.dart';

typedef AssetLoader = Future<String> Function(String path);

class SongCatalogService {
  static final SongCatalogService _instance = SongCatalogService._internal();
  factory SongCatalogService() => _instance;
  SongCatalogService._internal();

  // 允許測試注入
  AssetLoader assetLoader = (path) => rootBundle.loadString(path);

  Future<List<KtvSong>> loadSongs() async {
    try {
      final jsonString = await assetLoader('assets/audio/collect.json');
      final songs = KtvCollectionParser.parse(jsonString);
      return songs;
    } catch (_) {
      // 異常時回傳空清單，交由 UI 顯示空態/重試
      return const [];
    }
  }
}
