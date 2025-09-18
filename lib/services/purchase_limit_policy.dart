import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../services/config_service.dart';
import '../services/purchase_repository.dart';

/// 封裝商城商品的限購規則。
///
/// 依據 `store.json` 中的 `purchase_limit_type` 與 `purchase_max_count`
/// （非 limited 類型若未設定或 ≤ 0 則預設為 1），搭配本地儲存的購買計數，
/// 回傳當下是否可購買、剩餘名額以及記錄購買次數。
class PurchaseLimitPolicy {
  PurchaseLimitPolicy._({
    required Map<String, dynamic> storeConfig,
    required SharedPreferences preferences,
  })  : _storeConfig = storeConfig,
        _prefs = preferences {
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
    _taipei = tz.getLocation(_timezoneId);
  }

  final Map<String, dynamic> _storeConfig;
  final SharedPreferences _prefs;
  late final tz.Location _taipei;

  static bool _tzInitialized = false;
  static const String _timezoneId = 'Asia/Taipei';
  static const String firstLaunchKey = 'limit:first_launch_date';

  /// 建立實際環境使用的實例，讀取 `store.json` 與共用的購買存檔。
  static Future<PurchaseLimitPolicy> create({
    ConfigService? configService,
    PurchaseRepository? repository,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final config = (configService ?? ConfigService()).getStoreConfig();
    final repo = repository ?? PurchaseRepository();

    final installRecord = await repo.getInstallRecord();
    if (installRecord != null) {
      cacheInstallDate(installRecord.firstOpenDate, prefs);
      if (!(prefs.getString(firstLaunchKey)?.isNotEmpty ?? false)) {
        await prefs.setString(firstLaunchKey, installRecord.firstOpenDate);
      }
    }

    return PurchaseLimitPolicy._(
      storeConfig: config,
      preferences: prefs,
    );
  }

  /// 測試用工廠，允許注入指定配置與儲存。
  static PurchaseLimitPolicy forTest({
    required Map<String, dynamic> storeConfig,
    required SharedPreferences preferences,
  }) {
    return PurchaseLimitPolicy._(
      storeConfig: storeConfig,
      preferences: preferences,
    );
  }

  /// 檢查指定商品在 `now` 時刻是否仍可購買。
  bool canPurchase(String storeId, DateTime now) {
    final rule = _resolveRule(storeId);
    final tzNow = _toTaipei(now);

    switch (rule.type) {
      case _LimitType.unlimited:
        return true;
      case _LimitType.limited:
        final purchased = _getLimitedCount(storeId);
        return purchased < rule.maxCount;
      case _LimitType.daily:
        final key = _dailyKey(storeId, tzNow);
        final purchased = _prefs.getInt(key) ?? 0;
        return purchased < rule.maxCount;
      case _LimitType.monthly:
        final key = _monthlyKey(storeId, tzNow);
        final purchased = _prefs.getInt(key) ?? 0;
        return purchased < rule.maxCount;
      case _LimitType.first7:
        if (!_isWithinFirstPeriod(tzNow, 7)) {
          return false;
        }
        return _getLimitedCount(storeId) < rule.maxCount;
      case _LimitType.first30:
        if (!_isWithinFirstPeriod(tzNow, 30)) {
          return false;
        }
        return _getLimitedCount(storeId) < rule.maxCount;
    }
  }

  /// 紀錄一次購買行為，更新對應的限購計數。
  ///
  /// 呼叫端應自行先行確認 `canPurchase`，此處不重複檢查以維持同步版本。
  void recordPurchase(String storeId, DateTime now) {
    final rule = _resolveRule(storeId);
    final tzNow = _toTaipei(now);

    switch (rule.type) {
      case _LimitType.unlimited:
        return;
      case _LimitType.limited:
        _incrementLimitedCount(storeId);
        return;
      case _LimitType.daily:
        _incrementKey(_dailyKey(storeId, tzNow));
        return;
      case _LimitType.monthly:
        _incrementKey(_monthlyKey(storeId, tzNow));
        return;
      case _LimitType.first7:
      case _LimitType.first30:
        _incrementLimitedCount(storeId);
        return;
    }
  }

  /// 回傳在 `now` 時刻，當期剩餘可購次數。
  ///
  /// - `-1` 代表無上限（unlimited）。
  /// - 其他型別回傳 0 或正整數。
  int remainingQuota(String storeId, DateTime now) {
    final rule = _resolveRule(storeId);
    final tzNow = _toTaipei(now);

    switch (rule.type) {
      case _LimitType.unlimited:
        return -1;
      case _LimitType.limited:
        final purchased = _getLimitedCount(storeId);
        return _remaining(rule.maxCount, purchased);
      case _LimitType.daily:
        final purchased = _prefs.getInt(_dailyKey(storeId, tzNow)) ?? 0;
        return _remaining(rule.maxCount, purchased);
      case _LimitType.monthly:
        final purchased = _prefs.getInt(_monthlyKey(storeId, tzNow)) ?? 0;
        return _remaining(rule.maxCount, purchased);
      case _LimitType.first7:
        if (!_isWithinFirstPeriod(tzNow, 7)) {
          return 0;
        }
        return _remaining(rule.maxCount, _getLimitedCount(storeId));
      case _LimitType.first30:
        if (!_isWithinFirstPeriod(tzNow, 30)) {
          return 0;
        }
        return _remaining(rule.maxCount, _getLimitedCount(storeId));
    }
  }

  // ---- Helpers ----

  _Rule _resolveRule(String storeId) {
    final config = _storeConfig[storeId];
    if (config is! Map<String, dynamic>) {
      throw ArgumentError('storeId "$storeId" not found in store config');
    }

    final limitType = _parseLimitType(config['purchase_limit_type'] as String?);
    final rawMax = (config['purchase_max_count'] as int?) ?? 1;
    final normalized = rawMax <= 0 ? 1 : rawMax;

    switch (limitType) {
      case _LimitType.unlimited:
        return const _Rule(type: _LimitType.unlimited, maxCount: -1);
      case _LimitType.limited:
        return _Rule(type: _LimitType.limited, maxCount: normalized);
      case _LimitType.daily:
      case _LimitType.monthly:
      case _LimitType.first7:
      case _LimitType.first30:
        return _Rule(type: limitType, maxCount: normalized);
    }
  }

  _LimitType _parseLimitType(String? type) {
    switch (type) {
      case 'unlimited':
        return _LimitType.unlimited;
      case 'daily':
        return _LimitType.daily;
      case 'monthly':
        return _LimitType.monthly;
      case 'first7':
        return _LimitType.first7;
      case 'first30':
        return _LimitType.first30;
      case 'limited':
      default:
        return _LimitType.limited;
    }
  }

  tz.TZDateTime _toTaipei(DateTime time) {
    return tz.TZDateTime.from(time, _taipei);
  }

  int _getLimitedCount(String storeId) {
    return _prefs.getInt(_limitedKey(storeId)) ?? 0;
  }

  void _incrementLimitedCount(String storeId) {
    _incrementKey(_limitedKey(storeId));
  }

  void _incrementKey(String key) {
    final current = _prefs.getInt(key) ?? 0;
    unawaited(_prefs.setInt(key, current + 1));
  }

  int _remaining(int maxCount, int used) {
    final remaining = maxCount - used;
    return remaining <= 0 ? 0 : remaining;
  }

  bool _isWithinFirstPeriod(tz.TZDateTime now, int days) {
    final firstLaunch = _getFirstLaunch(now);
    final diffDays = now.difference(firstLaunch).inDays;
    return diffDays < days;
  }

  tz.TZDateTime _getFirstLaunch(tz.TZDateTime now) {
    final stored = _prefs.getString(firstLaunchKey);
    if (stored != null && stored.isNotEmpty) {
      return _parseDate(stored);
    }

    // 若 SharedPreferences 尚未寫入，嘗試從購買存檔取得首次啟動日
    final installDate = _repositoryCachedInstallDate ??
        _prefs.getString(_installCacheKey);
    if (installDate != null && installDate.isNotEmpty) {
      unawaited(_prefs.setString(firstLaunchKey, installDate));
      return _parseDate(installDate);
    }

    final today = _formatDate(now);
    unawaited(_prefs.setString(firstLaunchKey, today));
    return tz.TZDateTime(_taipei, now.year, now.month, now.day);
  }

  tz.TZDateTime _parseDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) {
      // fallback：若儲存格式異常，改用當前日期
      final now = tz.TZDateTime.now(_taipei);
      return tz.TZDateTime(_taipei, now.year, now.month, now.day);
    }

    final year = int.tryParse(parts[0]) ?? 1970;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    return tz.TZDateTime(_taipei, year, month, day);
  }

  String _limitedKey(String storeId) => 'limit:once:$storeId';
  String _dailyKey(String storeId, tz.TZDateTime now) =>
      'limit:daily:${_formatDate(now)}:$storeId';
  String _monthlyKey(String storeId, tz.TZDateTime now) =>
      'limit:monthly:${_formatYearMonth(now)}:$storeId';

  String _formatDate(tz.TZDateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatYearMonth(tz.TZDateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  // ---- Install-date 快取 ----
  static const String _installCacheKey = 'limit:first_launch_cache';
  static String? _repositoryCachedInstallDate;

  /// 設定來自購買存檔的首次啟動日期，供 Policy 使用。
  ///
  /// 目的：避免 `PurchaseLimitPolicy` 直接呼叫 async repository，保持同步 API。
  static void cacheInstallDate(String date, SharedPreferences prefs) {
    _repositoryCachedInstallDate = date;
    unawaited(prefs.setString(_installCacheKey, date));
  }
}

enum _LimitType { limited, unlimited, daily, monthly, first7, first30 }

class _Rule {
  const _Rule({required this.type, required this.maxCount});

  final _LimitType type;
  final int maxCount;
}
