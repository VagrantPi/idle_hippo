import 'dart:convert';
import 'package:flutter/services.dart';

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
      final equipmentsConfig = await _loadJsonFile('assets/config/equipments.json');
      final petsConfig = await _loadJsonFile('assets/config/pets.json');
      final titlesConfig = await _loadJsonFile('assets/config/titles.json');
      final questsConfig = await _loadJsonFile('assets/config/quests.json');

      // 合併所有配置到記憶體
      _configs = {
        'game': gameConfig,
        'equipments': equipmentsConfig,
        'pets': petsConfig,
        'titles': titlesConfig,
        'quests': questsConfig,
      };

      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  /// 載入單一 JSON 檔案
  Future<Map<String, dynamic>> _loadJsonFile(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
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
}
