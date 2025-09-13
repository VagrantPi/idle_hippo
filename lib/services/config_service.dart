import 'dart:convert';
import 'package:idle_hippo/services/asset_loader.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  Map<String, dynamic> _configs = {};
  bool _isLoaded = false;

  /// 載入所有配置檔案
  Future<void> loadConfig() async {
    try {
      // 載入所有配置檔案
      final gameConfig = await _loadJsonFile('assets/config/game.json');
      final equipmentsConfig = await _loadJsonFile(
        'assets/config/equipments.json',
      );
      final petsConfig = await _loadJsonFile('assets/config/pets.json');
      final titlesConfig = await _loadJsonFile('assets/config/titles.json');
      final questsConfig = await _loadJsonFile('assets/config/quests.json');
      // 商城配置（Step26）
      final storeConfig = await _loadJsonFile('assets/config/store.json');

      // 合併所有配置到記憶體
      _configs = {
        'game': gameConfig,
        'equipments': equipmentsConfig,
        'pets': petsConfig,
        'titles': titlesConfig,
        'quests': questsConfig,
        'store': storeConfig,
      };

      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  /// 向後相容：部分測試使用 initialize() 名稱
  /// 實際上等同於呼叫 loadConfig()
  Future<void> initialize() async {
    await loadConfig();
  }

  /// 載入單一 JSON 檔案
  Future<Map<String, dynamic>> _loadJsonFile(String path) async {
    try {
      final String jsonString = await loadAssetString(path);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// 取得配置值，支援路徑格式如 "game.tap.base"
  dynamic getValue(String path, {dynamic defaultValue}) {
    if (!_isLoaded) {
      return defaultValue;
    }

    try {
      final keys = path.split('.');
      dynamic current = _configs;
      // print("current: $current");

      for (final key in keys) {
        if (current is Map<String, dynamic> && current.containsKey(key)) {
          current = current[key];
        } else {
          return defaultValue;
        }
      }

      return current;
    } catch (e) {
      return defaultValue;
    }
  }

  /// 檢查配置是否已載入
  bool get isLoaded => _isLoaded;

  /// 取得所有配置（用於 debug）
  Map<String, dynamic> get allConfigs => Map.unmodifiable(_configs);

  /// 重新載入配置（支援 hot reload）
  Future<void> reload() async {
    _isLoaded = false;
    _configs.clear();
    await loadConfig();
  }

  /// 取得寵物配置
  Map<String, dynamic>? getPetConfig(String petKey) {
    if (!_isLoaded) return null;

    final petsConfig = _configs['pets'] as Map<String, dynamic>?;
    if (petsConfig == null) return null;

    final pets = petsConfig['pets'] as List<dynamic>?;
    if (pets == null) return null;

    for (final pet in pets) {
      if (pet is Map<String, dynamic> && pet['id'] == petKey) {
        return pet;
      }
    }

    return null;
  }

  /// 取得寵物某稀有度的配置（支援 per-pet override，否則回退到 default_rarities）
  Map<String, dynamic>? getPetRarityConfig(String petKey, String rarityKey) {
    if (!_isLoaded) return null;

    final petsConfig = _configs['pets'] as Map<String, dynamic>?;
    if (petsConfig == null) return null;

    // 1) 優先讀取該寵物自己的 rarities（向後相容）
    final pet = getPetConfig(petKey);
    final petRarities = pet != null
        ? pet['rarities'] as Map<String, dynamic>?
        : null;
    if (petRarities != null && petRarities.containsKey(rarityKey)) {
      final cfg = petRarities[rarityKey];
      return (cfg is Map<String, dynamic>) ? cfg : null;
    }

    // 2) 回退到全域 default_rarities
    final defaultRarities =
        petsConfig['default_rarities'] as Map<String, dynamic>?;
    if (defaultRarities != null && defaultRarities.containsKey(rarityKey)) {
      final cfg = defaultRarities[rarityKey];
      return (cfg is Map<String, dynamic>) ? cfg : null;
    }

    return null;
  }
}
