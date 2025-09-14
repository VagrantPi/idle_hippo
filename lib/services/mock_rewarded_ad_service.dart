import '../models/purchase_models.dart';
import 'purchase_service.dart';

/// Mock 獎勵廣告服務實作
/// 
/// 提供測試與開發階段使用的模擬廣告功能
class MockRewardedAdService implements RewardedAdService {
  @override
  Future<RewardedStatus> show(String placement, {String? productId}) async {
    // 模擬廣告播放時間
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock 廣告一律成功發放獎勵
    return RewardedStatus.rewarded;
  }
}
