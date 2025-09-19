import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 待補發紀錄
class PendingGrant {
  final String skuId;
  final String orderId;

  const PendingGrant({required this.skuId, required this.orderId});

  Map<String, dynamic> toJson() => {
        'skuId': skuId,
        'orderId': orderId,
      };

  factory PendingGrant.fromJson(Map<String, dynamic> json) {
    return PendingGrant(
      skuId: json['skuId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
    );
  }
}

/// 待補發儲存介面
abstract class PendingGrantStore {
  Future<void> save(PendingGrant pending);
  Future<PendingGrant?> load();
  Future<void> clear();
}

/// 使用 SharedPreferences 的持久化實作
class SharedPrefsPendingGrantStore implements PendingGrantStore {
  static const String _key = 'pending_grant';

  @override
  Future<void> save(PendingGrant pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json.encode(pending.toJson()));
    } catch (_) {}
  }

  @override
  Future<PendingGrant?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final map = json.decode(raw) as Map<String, dynamic>;
      return PendingGrant.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

/// 測試／預設用的記憶體實作（非持久化）
class InMemoryPendingGrantStore implements PendingGrantStore {
  Map<String, String>? _cache;

  @override
  Future<void> save(PendingGrant pending) async {
    _cache = {
      'skuId': pending.skuId,
      'orderId': pending.orderId,
    };
  }

  @override
  Future<PendingGrant?> load() async {
    final c = _cache;
    if (c == null) return null;
    return PendingGrant(skuId: c['skuId']!, orderId: c['orderId']!);
  }

  @override
  Future<void> clear() async {
    _cache = null;
  }
}

