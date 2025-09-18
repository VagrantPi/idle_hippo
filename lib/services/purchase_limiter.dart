import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/purchase_models.dart';
import '../services/config_service.dart';
import '../services/purchase_repository.dart';
import 'purchase_limit_policy.dart';
import 'purchase_service.dart';

/// 購買限制器實作
///
/// 依商品規則與當前時間、歷史購買資料，回傳可購買狀態
class PurchaseLimiterImpl implements PurchaseLimiter {
  final ConfigService _configService;
  final PurchaseRepository _repository;
  SharedPreferences? _prefs;
  PurchaseLimitPolicy? _policy;

  PurchaseLimiterImpl(this._configService, this._repository);

  @override
  Future<PurchaseAvailability> availability(
    String productId,
    DateTime nowLocal,
  ) async {
    await ensureRollovers(nowLocal);

    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    if (productConfig == null) {
      return const PurchaseAvailability(
        false,
        reasonKey: 'store.unavailable.product_not_found',
      );
    }

    final policy = await _getPolicy();
    await _syncFirstLaunchDate(nowLocal);

    final limitType =
        _parseLimitType(productConfig['purchase_limit_type'] as String?);
    final canBuy = policy.canPurchase(productId, nowLocal);
    final remaining = policy.remainingQuota(productId, nowLocal);

    if (canBuy) {
      return PurchaseAvailability(true, remaining: remaining);
    }

    final record = await _repository.getPurchaseRecord(productId);
    final reasonKey = await _resolveReasonKey(limitType, record, nowLocal);
    final nonNegativeRemaining = remaining < 0 ? 0 : remaining;
    return PurchaseAvailability(
      false,
      reasonKey: reasonKey,
      remaining: nonNegativeRemaining,
    );
  }

  @override
  Future<void> markPurchased(String productId, DateTime nowLocal) async {
    await ensureRollovers(nowLocal);

    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    if (productConfig == null) return;

    final policy = await _getPolicy();
    await _syncFirstLaunchDate(nowLocal);
    policy.recordPurchase(productId, nowLocal);

    final limitType =
        _parseLimitType(productConfig['purchase_limit_type'] as String?);
    var record =
        await _repository.getPurchaseRecord(productId) ?? const PurchaseRecord();

    switch (limitType) {
      case LimitType.unlimited:
      case LimitType.limited:
        // 更新總計數
        final newTotal = (record.total ?? 0) + 1;
        record = record.copyWith(total: newTotal);
        break;

      case LimitType.daily:
        final currentDate = _formatDate(nowLocal);
        final dailyRecord = record.daily;

        if (dailyRecord == null || dailyRecord.date != currentDate) {
          // 新的一天
          record = record.copyWith(
            daily: DailyRecord(date: currentDate, count: 1),
          );
        } else {
          // 同一天，累加
          record = record.copyWith(
            daily: dailyRecord.copyWith(count: dailyRecord.count + 1),
          );
        }
        break;

      case LimitType.monthly:
        final currentYm = _formatYearMonth(nowLocal);
        final monthlyRecord = record.monthly;

        if (monthlyRecord == null || monthlyRecord.ym != currentYm) {
          // 新的月份
          record = record.copyWith(
            monthly: MonthlyRecord(ym: currentYm, count: 1),
          );
        } else {
          // 同一月，累加
          record = record.copyWith(
            monthly: monthlyRecord.copyWith(count: monthlyRecord.count + 1),
          );
        }
        break;

      case LimitType.first7:
      case LimitType.first30:
        // 新手期商品也需要記錄總計數
        final newTotal = (record.total ?? 0) + 1;
        record = record.copyWith(total: newTotal);
        break;
    }

    await _repository.savePurchaseRecord(productId, record);
  }

  @override
  Future<void> ensureRollovers(DateTime nowLocal) async {
    await _repository.resetDailyRecords(nowLocal);
    await _repository.resetMonthlyRecords(nowLocal);
  }

  Future<PurchaseLimitPolicy> _getPolicy() async {
    if (_policy != null) {
      return _policy!;
    }
    _prefs ??= await SharedPreferences.getInstance();
    _policy = await PurchaseLimitPolicy.create(
      configService: _configService,
      repository: _repository,
      preferences: _prefs!,
    );
    return _policy!;
  }

  Future<void> _syncFirstLaunchDate(DateTime nowLocal) async {
    _prefs ??= await SharedPreferences.getInstance();
    final installRecord = await _repository.ensureInstallRecord(nowLocal);
    PurchaseLimitPolicy.cacheInstallDate(installRecord.firstOpenDate, _prefs!);
    if (!(_prefs!
            .getString(PurchaseLimitPolicy.firstLaunchKey)
            ?.isNotEmpty ??
        false)) {
      await _prefs!.setString(
        PurchaseLimitPolicy.firstLaunchKey,
        installRecord.firstOpenDate,
      );
    }
  }

  Future<String> _resolveReasonKey(
    LimitType type,
    PurchaseRecord? record,
    DateTime nowLocal,
  ) async {
    switch (type) {
      case LimitType.unlimited:
        return 'store.unavailable.limited_cap';
      case LimitType.limited:
        return 'store.unavailable.limited_cap';
      case LimitType.daily:
        return 'store.unavailable.daily_cap';
      case LimitType.monthly:
        return 'store.unavailable.monthly_cap';
      case LimitType.first7:
        return await _firstPeriodReason(
          record,
          nowLocal,
          7,
          'store.unavailable.first7_expired',
        );
      case LimitType.first30:
        return await _firstPeriodReason(
          record,
          nowLocal,
          30,
          'store.unavailable.first30_expired',
        );
    }
  }

  Future<String> _firstPeriodReason(
    PurchaseRecord? record,
    DateTime nowLocal,
    int days,
    String expiredKey,
  ) async {
    if ((record?.total ?? 0) > 0) {
      return 'store.unavailable.limited_cap';
    }

    final installRecord = await _repository.ensureInstallRecord(nowLocal);
    final launchDate = installRecord.firstOpenDate;
    final location = tz.getLocation('Asia/Taipei');
    final first = _parseDateString(launchDate, location);
    final now = tz.TZDateTime.from(nowLocal, location);
    final diffDays = now.difference(first).inDays;

    if (diffDays >= days) {
      return expiredKey;
    }

    return 'store.unavailable.limited_cap';
  }

  tz.TZDateTime _parseDateString(String date, tz.Location location) {
    final parts = date.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return tz.TZDateTime(location, year, month, day);
  }

  /// 解析限購類型
  LimitType _parseLimitType(String? typeStr) {
    switch (typeStr) {
      case 'unlimited':
        return LimitType.unlimited;
      case 'limited':
        return LimitType.limited;
      case 'daily':
        return LimitType.daily;
      case 'monthly':
        return LimitType.monthly;
      case 'first7':
        return LimitType.first7;
      case 'first30':
        return LimitType.first30;
      default:
        return LimitType.limited; // 預設為限購
    }
  }

  /// 格式化日期為 YYYY-MM-DD (Asia/Taipei)
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  /// 格式化年月為 YYYY-MM (Asia/Taipei)
  String _formatYearMonth(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}';
  }
}
