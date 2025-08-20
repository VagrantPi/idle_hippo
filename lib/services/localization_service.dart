import 'dart:convert';
import 'package:flutter/services.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Map<String, dynamic> _localizedStrings = {};
  String _currentLanguage = 'en';
  
  // 支援的語言
  static const List<String> supportedLanguages = ['en', 'zh', 'jp', 'ko'];
  
  // 語言顯示名稱
  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '繁體中文',
    'jp': '日本語',
    'ko': '한국어',
  };

  String get currentLanguage => _currentLanguage;

  /// 初始化多語系服務
  Future<void> init({String? language}) async {
    _currentLanguage = language ?? 'en';
    await _loadLanguage(_currentLanguage);
  }

  /// 載入指定語言的字串資源
  Future<void> _loadLanguage(String languageCode) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/lang/$languageCode.json');
      _localizedStrings = json.decode(jsonString);
      print('LocalizationService: Loaded language $languageCode');
    } catch (e) {
      print('LocalizationService: Failed to load language $languageCode: $e');
      // 載入失敗時使用英文作為備用
      if (languageCode != 'en') {
        await _loadLanguage('en');
      }
    }
  }

  /// 切換語言
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLanguages.contains(languageCode)) {
      print('LocalizationService: Unsupported language: $languageCode');
      return;
    }
    
    if (_currentLanguage == languageCode) return;
    
    _currentLanguage = languageCode;
    await _loadLanguage(languageCode);
  }

  /// 取得本地化字串
  String getString(String key, {String? defaultValue}) {
    final keys = key.split('.');
    dynamic current = _localizedStrings;
    
    for (final k in keys) {
      if (current is Map<String, dynamic> && current.containsKey(k)) {
        current = current[k];
      } else {
        return defaultValue ?? key;
      }
    }
    
    return current?.toString() ?? defaultValue ?? key;
  }

  /// 便捷方法：取得頁面名稱
  String getPageName(String pageKey) {
    return getString('pages.$pageKey');
  }

  /// 便捷方法：取得通用文字
  String getCommon(String commonKey) {
    return getString('common.$commonKey');
  }

  /// 便捷方法：取得 UI 文字
  String getUI(String uiKey) {
    return getString('ui.$uiKey');
  }
}
