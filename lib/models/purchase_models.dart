/// 購買相關的資料模型與抽象介面定義
///
/// 提供購買商品資訊、購買事件、購買狀態等核心資料結構
library;

/// 商品資訊
class ProductInfo {
  final String id; // 商品 ID（= store.* key）
  final String name; // UI 端自行做 i18n 映射
  final String desc;
  final String image;
  final double? price; // Mock 可填，IAP 由 SDK 回傳
  final String? currency;

  const ProductInfo({
    required this.id,
    required this.name,
    required this.desc,
    required this.image,
    this.price,
    this.currency,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          desc == other.desc &&
          image == other.image &&
          price == other.price &&
          currency == other.currency;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      desc.hashCode ^
      image.hashCode ^
      price.hashCode ^
      currency.hashCode;

  @override
  String toString() {
    return 'ProductInfo{id: $id, name: $name, price: $price, currency: $currency}';
  }
}

/// 購買狀態
enum PurchaseStatus { pending, success, canceled, error }

/// 購買事件
class PurchaseEvent {
  final String productId;
  final PurchaseStatus status;
  final String? message; // 錯誤訊息、取消原因等

  const PurchaseEvent({
    required this.productId,
    required this.status,
    this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseEvent &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          status == other.status &&
          message == other.message;

  @override
  int get hashCode => productId.hashCode ^ status.hashCode ^ message.hashCode;

  @override
  String toString() {
    return 'PurchaseEvent{productId: $productId, status: $status, message: $message}';
  }
}

/// 獎勵廣告狀態
enum RewardedStatus { opened, rewarded, closed, error }

/// 限購類型
enum LimitType { limited, unlimited, daily, monthly, first7, first30 }

/// 購買可用性狀態
class PurchaseAvailability {
  final bool canBuy;
  final String?
  reasonKey; // i18n key: e.g. store.unavailable.daily_cap, store.unavailable.first7_expired
  final int remaining; // 本視窗期內剩餘次數（-1 表示無上限）

  const PurchaseAvailability(
    this.canBuy, {
    this.reasonKey,
    this.remaining = -1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseAvailability &&
          runtimeType == other.runtimeType &&
          canBuy == other.canBuy &&
          reasonKey == other.reasonKey &&
          remaining == other.remaining;

  @override
  int get hashCode => canBuy.hashCode ^ reasonKey.hashCode ^ remaining.hashCode;

  @override
  String toString() {
    return 'PurchaseAvailability{canBuy: $canBuy, reasonKey: $reasonKey, remaining: $remaining}';
  }
}

/// 購買記錄資料結構
class PurchaseRecord {
  final int? total;
  final DailyRecord? daily;
  final MonthlyRecord? monthly;

  const PurchaseRecord({this.total, this.daily, this.monthly});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (total != null) json['total'] = total;
    if (daily != null) json['daily'] = daily!.toJson();
    if (monthly != null) json['monthly'] = monthly!.toJson();
    return json;
  }

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      total: json['total'] as int?,
      daily: json['daily'] != null
          ? DailyRecord.fromJson(json['daily'] as Map<String, dynamic>)
          : null,
      monthly: json['monthly'] != null
          ? MonthlyRecord.fromJson(json['monthly'] as Map<String, dynamic>)
          : null,
    );
  }

  PurchaseRecord copyWith({
    int? total,
    DailyRecord? daily,
    MonthlyRecord? monthly,
  }) {
    return PurchaseRecord(
      total: total ?? this.total,
      daily: daily ?? this.daily,
      monthly: monthly ?? this.monthly,
    );
  }
}

/// 每日購買記錄
class DailyRecord {
  final String date; // YYYY-MM-DD (Asia/Taipei)
  final int count;

  const DailyRecord({required this.date, required this.count});

  Map<String, dynamic> toJson() => {'date': date, 'count': count};

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      date: json['date'] as String,
      count: json['count'] as int,
    );
  }

  DailyRecord copyWith({String? date, int? count}) {
    return DailyRecord(date: date ?? this.date, count: count ?? this.count);
  }
}

/// 每月購買記錄
class MonthlyRecord {
  final String ym; // YYYY-MM (Asia/Taipei)
  final int count;

  const MonthlyRecord({required this.ym, required this.count});

  Map<String, dynamic> toJson() => {'ym': ym, 'count': count};

  factory MonthlyRecord.fromJson(Map<String, dynamic> json) {
    return MonthlyRecord(ym: json['ym'] as String, count: json['count'] as int);
  }

  MonthlyRecord copyWith({String? ym, int? count}) {
    return MonthlyRecord(ym: ym ?? this.ym, count: count ?? this.count);
  }
}

/// 安裝記錄
class InstallRecord {
  final String firstOpenDate; // YYYY-MM-DD (Asia/Taipei)

  const InstallRecord({required this.firstOpenDate});

  Map<String, dynamic> toJson() => {'firstOpenDate': firstOpenDate};

  factory InstallRecord.fromJson(Map<String, dynamic> json) {
    return InstallRecord(firstOpenDate: json['firstOpenDate'] as String);
  }
}
