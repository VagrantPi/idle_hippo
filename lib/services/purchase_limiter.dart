import '../models/purchase_models.dart';
import '../services/config_service.dart';
import '../services/purchase_repository.dart';
import 'purchase_service.dart';

/// 購買限制器實作
/// 
/// 依商品規則與當前時間、歷史購買資料，回傳可購買狀態
class PurchaseLimiterImpl implements PurchaseLimiter {
  final ConfigService _configService;
  final PurchaseRepository _repository;

  PurchaseLimiterImpl(this._configService, this._repository);

  @override
  Future<PurchaseAvailability> availability(String productId, DateTime nowLocal) async {
    // 確保跨日/跨月重置
    await ensureRollovers(nowLocal);
    
    // 取得商品設定
    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    
    if (productConfig == null) {
      return const PurchaseAvailability(false, reasonKey: 'store.unavailable.product_not_found');
    }
    
    final limitType = _parseLimitType(productConfig['purchase_limit_type'] as String?);
    final maxCount = productConfig['purchase_max_count'] as int? ?? 1;
    
    // 取得購買記錄
    final record = await _repository.getPurchaseRecord(productId);
    
    switch (limitType) {
      case LimitType.unlimited:
        return const PurchaseAvailability(true, remaining: -1);
        
      case LimitType.limited:
        final totalPurchased = record?.total ?? 0;
        final remaining = maxCount - totalPurchased;
        if (remaining > 0) {
          return PurchaseAvailability(true, remaining: remaining);
        } else {
          return const PurchaseAvailability(false, reasonKey: 'store.unavailable.limited_cap', remaining: 0);
        }
        
      case LimitType.daily:
        final currentDate = _formatDate(nowLocal);
        final dailyRecord = record?.daily;
        
        if (dailyRecord == null || dailyRecord.date != currentDate) {
          // 新的一天或首次購買
          return PurchaseAvailability(true, remaining: maxCount);
        } else {
          final remaining = maxCount - dailyRecord.count;
          if (remaining > 0) {
            return PurchaseAvailability(true, remaining: remaining);
          } else {
            return const PurchaseAvailability(false, reasonKey: 'store.unavailable.daily_cap', remaining: 0);
          }
        }
        
      case LimitType.monthly:
        final currentYm = _formatYearMonth(nowLocal);
        final monthlyRecord = record?.monthly;
        
        if (monthlyRecord == null || monthlyRecord.ym != currentYm) {
          // 新的月份或首次購買
          return PurchaseAvailability(true, remaining: maxCount);
        } else {
          final remaining = maxCount - monthlyRecord.count;
          if (remaining > 0) {
            return PurchaseAvailability(true, remaining: remaining);
          } else {
            return const PurchaseAvailability(false, reasonKey: 'store.unavailable.monthly_cap', remaining: 0);
          }
        }
        
      case LimitType.first7:
        return await _checkFirstNDays(productId, nowLocal, 7, 'store.unavailable.first7_expired');
        
      case LimitType.first30:
        return await _checkFirstNDays(productId, nowLocal, 30, 'store.unavailable.first30_expired');
    }
  }

  @override
  Future<void> markPurchased(String productId, DateTime nowLocal) async {
    // 確保跨日/跨月重置
    await ensureRollovers(nowLocal);
    
    // 取得商品設定
    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    
    if (productConfig == null) return;
    
    final limitType = _parseLimitType(productConfig['purchase_limit_type'] as String?);
    
    // 取得現有記錄
    var record = await _repository.getPurchaseRecord(productId) ?? const PurchaseRecord();
    
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

  /// 檢查新手期商品可購買性
  Future<PurchaseAvailability> _checkFirstNDays(
    String productId,
    DateTime nowLocal,
    int days,
    String expiredReasonKey,
  ) async {
    // 確保安裝記錄存在
    final installRecord = await _repository.ensureInstallRecord(nowLocal);
    final firstOpenDate = DateTime.parse(installRecord.firstOpenDate);
    
    // 計算天數差異
    final daysDiff = nowLocal.difference(firstOpenDate).inDays;
    
    if (daysDiff >= days) {
      // 超過新手期
      return PurchaseAvailability(false, reasonKey: expiredReasonKey, remaining: 0);
    }
    
    // 在新手期內，檢查是否已購買過
    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    final maxCount = productConfig?['purchase_max_count'] as int? ?? 1;
    
    final record = await _repository.getPurchaseRecord(productId);
    final totalPurchased = record?.total ?? 0;
    final remaining = maxCount - totalPurchased;
    
    if (remaining > 0) {
      return PurchaseAvailability(true, remaining: remaining);
    } else {
      return const PurchaseAvailability(false, reasonKey: 'store.unavailable.limited_cap', remaining: 0);
    }
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
