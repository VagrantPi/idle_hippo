import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/ui/components/slide_in_dialog.dart';

/// 處理觀看激勵廣告後通用流程的服務
class RewardedAdService {
  // 單例實作，確保各處取得同一實例
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();
  static bool _tzInitialized = false;
  // --- Daily Gacha Ten-Pack Ad Quota Management ---
  late GameStateService _gameStateService;
  final ConfigService _configService = ConfigService();
  bool _initialized = false;

  final StreamController<int> _remainingGachaTenPackAdController =
      StreamController<int>.broadcast();
  Stream<int> get remainingGachaTenPackAdStream =>
      _remainingGachaTenPackAdController.stream;

  /// 測試初始化：允許注入 mock GameStateService
  Future<void> initializeForTest(GameStateService gameStateService) async {
    // 確保 timezone database 已初始化（idempotent）
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
    _gameStateService = gameStateService;
    _gameStateService.gameState.addListener(_emitRemainingGachaTenPackAd);
    _initialized = true;
    await _resetDailyGachaAdStateIfNeeded();
    // 立刻發送一次目前剩餘次數，避免測試時收不到初始值
    _emitRemainingGachaTenPackAd();
  }

  /// 正式環境初始化：注入既有的 GameStateService 實例
  Future<void> initialize(GameStateService gameStateService) async {
    await initializeForTest(gameStateService);
  }

  void dispose() {
    _remainingGachaTenPackAdController.close();
    _gameStateService.gameState.removeListener(_emitRemainingGachaTenPackAd);
  }

  void _emitRemainingGachaTenPackAd() async {
    final remaining = await getRemainingGachaTenPackAd();
    if (!_remainingGachaTenPackAdController.isClosed) {
      _remainingGachaTenPackAdController.sink.add(remaining);
    }
  }

  String _currentDateTaipei() {
    final location = tz.getLocation('Asia/Taipei');
    final now = tz.TZDateTime.now(location);
    return DateFormat('yyyy-MM-dd').format(now);
  }

  Future<void> _resetDailyGachaAdStateIfNeeded() async {
    if (!_initialized) return;
    final currentState = _gameStateService.gameState.value;
    final gachaState = currentState.gacha ?? GachaState.initial();
    final today = _currentDateTaipei();

    if (gachaState.lastDate != today) {
      final dailyLimit = _configService.getValue(
            'game.gacha.daily_ad_draw_limit',
            defaultValue: 1,
          ) as int;
      final updatedGachaState = gachaState.copyWith(
        lastDate: today,
        tenPackAdRemaining: dailyLimit,
      );
      await _gameStateService
          .updateGameState(currentState.copyWith(gacha: updatedGachaState));
    }
  }

  /// 是否可顯示十連廣告抽卡（會自動執行每日重置判定）
  Future<bool> canShowGachaTenPackAd() async {
    await _resetDailyGachaAdStateIfNeeded();
    final gachaState =
        _gameStateService.gameState.value.gacha ?? GachaState.initial();
    return gachaState.tenPackAdRemaining > 0;
  }

  /// 消耗一次十連廣告抽卡配額（成功返回 true）
  Future<bool> consumeGachaTenPackAd() async {
    if (!await canShowGachaTenPackAd()) return false;

    final currentState = _gameStateService.gameState.value;
    final gachaState = currentState.gacha!;
    final updated = gachaState.copyWith(
      tenPackAdRemaining: gachaState.tenPackAdRemaining - 1,
    );
    await _gameStateService
        .updateGameState(currentState.copyWith(gacha: updated));
    return true;
  }

  /// 取得當日剩餘十連廣告抽卡次數
  Future<int> getRemainingGachaTenPackAd() async {
    await _resetDailyGachaAdStateIfNeeded();
    return _gameStateService.gameState.value.gacha?.tenPackAdRemaining ?? 0;
  }

  /// 顯示一個模擬的激勵廣告流程
  ///
  /// [context] BuildContext 用於顯示對話框
  /// [onAdWatched] 廣告觀看完成後的回調，執行實際的獎勵邏輯
  /// [dialogTitle] 成功通知的標題
  /// [rewardContent] 成功通知中顯示獎勵內容的 Widget
  Future<void> showAd({
    required BuildContext context,
    required Future<void> Function() onAdWatched,
    required String dialogTitle,
    required Widget rewardContent,
  }) async {
    // 1. 模擬觀看廣告
    await Future.delayed(const Duration(seconds: 3));

    // 2. 執行實際的獎勵邏輯 (例如：發放獎勵、存檔)
    await onAdWatched();

    // 3. 顯示成功通知
    if (context.mounted) {
      _showSuccessDialog(context, dialogTitle, rewardContent);
    }
  }

  void _showSuccessDialog(BuildContext context, String title, Widget content) {
    final localization = LocalizationService();
    final ok = localization.getString('offline.confirm', defaultValue: 'Claim');

    showTopSlideDialog(
      context,
      barrierDismissible: true,
      child: Builder(
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xCC113300),
                    Color(0xCC1F5E1F),
                  ],
                ),
                border: Border.all(color: const Color(0xFF00FFD1).withValues(alpha: 0.8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFD1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00FFD1), width: 1),
                        ),
                        child: const Icon(Icons.check_circle, color: Color(0xFF00FFD1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  content, // 顯示傳入的獎勵內容
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F5E1F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF00FFD1), width: 2),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            ok,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> reset() async {
    if (!_initialized) return;
    final current = _gameStateService.gameState.value;
    final today = _currentDateTaipei();
    final updatedGacha = (current.gacha ?? GachaState.initial()).copyWith(
      lastDate: today,
      tenPackAdRemaining: 1,
    );
    await _gameStateService.updateGameState(
      current.copyWith(gacha: updatedGacha),
    );
  }
}
