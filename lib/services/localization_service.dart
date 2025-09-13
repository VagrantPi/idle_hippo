import 'dart:convert';
import 'package:idle_hippo/services/asset_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Map<String, dynamic> _localizedStrings = {};
  String _currentLanguage = 'en';
  static const String _prefsKeyLanguage = 'settings.language';

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
    // 參數優先於已儲存的語系；否則使用已儲存或預設 zh
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKeyLanguage)?.trim();
      String lang;
      if (language != null && supportedLanguages.contains(language)) {
        lang = language;
      } else if (saved != null && supportedLanguages.contains(saved)) {
        lang = saved;
      } else {
        // 若呼叫端提供了語言但不受支援，統一回退英文，
        // 以符合測試期望與更直覺的預設。
        lang = 'en';
      }
      _currentLanguage = lang;
      await _loadLanguage(lang);
      // 初始化時也持久化一次，確保後續一致
      try {
        await prefs.setString(_prefsKeyLanguage, lang);
      } catch (_) {}
    } catch (_) {
      final fallback =
          (language != null && supportedLanguages.contains(language))
          ? language
          : 'en';
      _currentLanguage = fallback;
      await _loadLanguage(_currentLanguage);
    }
  }

  /// 載入指定語言的字串資源
  Future<void> _loadLanguage(String languageCode) async {
    try {
      final String jsonString = await loadAssetString(
        'assets/lang/$languageCode.json',
      );
      _localizedStrings = json.decode(jsonString);
      _currentLanguage = languageCode; // 確保更新當前語言
    } catch (e) {
      // 載入失敗時嘗試使用英文字串作為備用，但不改變 currentLanguage
      if (languageCode != 'en') {
        try {
          final String jsonString = await loadAssetString('assets/lang/en.json');
          _localizedStrings = json.decode(jsonString);
          // 保持 _currentLanguage 為原請求語言，以便外部狀態與 UI 顯示一致
        } catch (_) {
          // 英文也失敗則保持現狀
        }
      }
    }
  }

  /// 切換語言
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLanguages.contains(languageCode)) {
      return;
    }
    
    if (_currentLanguage == languageCode) return;

    _currentLanguage = languageCode;
    await _loadLanguage(languageCode);

    

    // 持久化目前語系
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyLanguage, languageCode);
    } catch (_) {}
  }

  /// 取得本地化字串
  String getString(
    String key, {
    Map<String, String>? replacements,
    String? defaultValue,
  }) {
    final keys = key.split('.');
    dynamic current = _localizedStrings;

    for (final k in keys) {
      if (current is Map<String, dynamic> && current.containsKey(k)) {
        current = current[k];
      } else {
        return defaultValue ?? key;
      }
    }

    String result = current?.toString() ?? defaultValue ?? key;

    if (replacements != null) {
      replacements.forEach((placeholder, value) {
        result = result.replaceAll('{$placeholder}', value);
      });
    }

    return result;
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

  /// 便捷方法：取得 offline 文字
  String getOffline(String offlineKey) {
    return getString('offline.$offlineKey');
  }
}
