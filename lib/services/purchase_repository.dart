import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/purchase_models.dart';

/// 購買記錄持久化服務
///
/// 負責儲存與讀取購買記錄、安裝記錄
/// 支援跨日/跨月重置邏輯
class PurchaseRepository {
  static const String _storeKey = 'purchase_store';

  PurchaseRepository();

  /// 取得商品購買記錄
  Future<PurchaseRecord?> getPurchaseRecord(String productId) async {
    final data = await _loadStoreData();
    final purchases = data['purchases'] as Map<String, dynamic>? ?? {};
    final recordData = purchases[productId] as Map<String, dynamic>?;

    if (recordData == null) return null;

    return PurchaseRecord.fromJson(recordData);
  }

  /// 儲存商品購買記錄
  Future<void> savePurchaseRecord(
    String productId,
    PurchaseRecord record,
  ) async {
    final data = await _loadStoreData();
    final purchases = data['purchases'] as Map<String, dynamic>? ?? {};
    purchases[productId] = record.toJson();
    data['purchases'] = purchases;

    await _saveStoreData(data);
  }

  /// 取得安裝記錄
  Future<InstallRecord?> getInstallRecord() async {
    final data = await _loadStoreData();
    final installData = data['install'] as Map<String, dynamic>?;

    if (installData == null) return null;

    return InstallRecord.fromJson(installData);
  }

  /// 儲存安裝記錄
  Future<void> saveInstallRecord(InstallRecord record) async {
    final data = await _loadStoreData();
    data['install'] = record.toJson();

    await _saveStoreData(data);
  }

  /// 確保安裝記錄存在（首次開啟時建立）
  Future<InstallRecord> ensureInstallRecord(DateTime nowLocal) async {
    var record = await getInstallRecord();
    if (record == null) {
      final dateStr = _formatDate(nowLocal);
      record = InstallRecord(firstOpenDate: dateStr);
      await saveInstallRecord(record);
    }
    return record;
  }

  /// 重置每日購買記錄（跨日時呼叫）
  Future<void> resetDailyRecords(DateTime nowLocal) async {
    final data = await _loadStoreData();
    final purchases = data['purchases'] as Map<String, dynamic>? ?? {};
    final currentDate = _formatDate(nowLocal);

    bool hasChanges = false;

    for (final entry in purchases.entries) {
      final recordData = entry.value as Map<String, dynamic>;
      final dailyData = recordData['daily'] as Map<String, dynamic>?;

      if (dailyData != null) {
        final recordDate = dailyData['date'] as String;
        if (recordDate != currentDate) {
          // 跨日重置
          recordData['daily'] = {'date': currentDate, 'count': 0};
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      data['purchases'] = purchases;
      await _saveStoreData(data);
    }
  }

  /// 重置每月購買記錄（跨月時呼叫）
  Future<void> resetMonthlyRecords(DateTime nowLocal) async {
    final data = await _loadStoreData();
    final purchases = data['purchases'] as Map<String, dynamic>? ?? {};
    final currentYm = _formatYearMonth(nowLocal);

    bool hasChanges = false;

    for (final entry in purchases.entries) {
      final recordData = entry.value as Map<String, dynamic>;
      final monthlyData = recordData['monthly'] as Map<String, dynamic>?;

      if (monthlyData != null) {
        final recordYm = monthlyData['ym'] as String;
        if (recordYm != currentYm) {
          // 跨月重置
          recordData['monthly'] = {'ym': currentYm, 'count': 0};
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      data['purchases'] = purchases;
      await _saveStoreData(data);
    }
  }

  /// 載入商城資料
  Future<Map<String, dynamic>> _loadStoreData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storeKey);
      if (jsonStr == null || jsonStr.isEmpty) return {};
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// 儲存商城資料
  Future<void> _saveStoreData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(data);
      await prefs.setString(_storeKey, jsonStr);
    } catch (e) {
      // 忽略儲存錯誤
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
