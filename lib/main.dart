import 'dart:async';
import 'package:flutter/material.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/game_clock_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';
import 'package:idle_hippo/services/secure_save_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/tap_service.dart';
import 'package:idle_hippo/services/daily_tap_service.dart';
import 'package:idle_hippo/services/equipment_service.dart';
import 'package:idle_hippo/services/offline_reward_service.dart';
import 'package:idle_hippo/ui/main_screen.dart';
import 'package:idle_hippo/ui/debug_panel.dart';
import 'package:idle_hippo/services/decimal_utils.dart';

void main() {
  runApp(const IdleHippoApp());
}

class IdleHippoApp extends StatelessWidget {
  final bool testMode;
  const IdleHippoApp({super.key, this.testMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Hippo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: IdleHippoScreen(testMode: testMode),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IdleHippoScreen extends StatefulWidget {
  final bool testMode;
  const IdleHippoScreen({super.key, this.testMode = false});

  @override
  State<IdleHippoScreen> createState() => _IdleHippoScreenState();
}

class _IdleHippoScreenState extends State<IdleHippoScreen> {
  final ConfigService _configService = ConfigService();
  final SecureSaveService _saveService = SecureSaveService();
  final GameClockService _gameClock = GameClockService();
  final IdleIncomeService _idleIncome = IdleIncomeService();
  final LocalizationService _localization = LocalizationService();
  final TapService _tapService = TapService();
  final DailyTapService _dailyTap = DailyTapService();
  final EquipmentService _equipment = EquipmentService();
  final OfflineRewardService _offline = OfflineRewardService();

  late GameState _gameState;
  Timer? _autoSaveTimer;
  Timer? _uiUpdateTimer;
  bool _showDebugPanel = false;
  double _lastTapDisplayValue = 0.0; // base + sum(equipment bonus)

  // 累積的放置收益（使用 double 避免小數被截斷）
  double _accumulatedIdleIncome = 0.0;
  // 移除不再需要的累積小數變數
  Timer? _tapFracTimer;

  @override
  void initState() {
    super.initState();
    _gameState = GameState.initial(_saveService.currentVersion);
    _initializeGame();
    _startAutoSaveTimer();
  }

  Future<void> _initializeGame() async {
    // 初始化 GameClock（註冊生命週期監聽與單調計時）
    _gameClock.init();
    await _initializeFromConfig();
    await _initializeLocalization();
    await _loadGameState();
    _initOfflineModule();
    // 測試模式：若尚無離線基準，建立 baseline，讓 simulateAddSeconds 能立即結算
    if (widget.testMode && _gameState.offline.lastExitUtcMs <= 0) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final snapshot = _idleIncome.currentIdlePerSec;
      setState(() {
        _gameState = _gameState.copyWith(
          offline: _gameState.offline.copyWith(
            lastExitUtcMs: now,
            idleRateSnapshot: snapshot,
          ),
        );
      });
      await _saveGameState();
    }
    
    // 測試模式下不啟動時間系統，避免測試 pumpAndSettle 永不穩定
    if (!widget.testMode) {
      // 確保 IdleIncome 初始化完成後再啟動時間系統
      _gameClock.start();
    }
  }

  Future<void> _initializeFromConfig() async {
    try {
      await _configService.loadConfig();
      print('Config loaded successfully');
      // 初始值可由設定檔控制是否顯示 DebugPanel
      final initialShow = _configService.getValue('game.ui.showDebugPanel', defaultValue: false);
      if (mounted && initialShow is bool) {
        setState(() {
          _showDebugPanel = initialShow;
        });
      }
    } catch (e) {
      print('Failed to load config: $e');
    }
  }

  Future<void> _initializeLocalization() async {
    try {
      await _localization.init(language: 'zh'); // 預設使用繁體中文
      print('Localization initialized');
    } catch (e) {
      print('Failed to initialize localization: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _uiUpdateTimer?.cancel();
    _tapFracTimer?.cancel();
    _gameClock.dispose();
    _idleIncome.dispose();
    _offline.dispose();
    super.dispose();
  }

  Future<void> _loadGameState() async {
    if (widget.testMode) {
      // 測試模式：不觸發 SecureSaveService，使用記憶體初始狀態
      setState(() {
        _gameState = GameState.initial(_saveService.currentVersion);
      });
    } else {
      try {
        final loadedState = await _saveService.load();
        setState(() {
          _gameState = loadedState;
        });
        print('Game state loaded: ${_gameState.memePoints} meme points');
      } catch (e) {
        print('Failed to load game state: $e');
      }
    }
    
    // 統一在這裡初始化放置收益系統
    _idleIncome.init(onIncomeGenerated: (double points) {
      _accumulatedIdleIncome = DecimalUtils.add(_accumulatedIdleIncome, points);
      
      // 當累積收益 >= 1 時才更新 GameState
      if (_accumulatedIdleIncome >= 1.0) {
        final pointsToAdd = _accumulatedIdleIncome.floor();
        _accumulatedIdleIncome = DecimalUtils.subtract(_accumulatedIdleIncome, pointsToAdd);
        
        setState(() {
          _gameState = _gameState.copyWith(
            memePoints: DecimalUtils.add(_gameState.memePoints, pointsToAdd),
          );
        });
      }
    });
    
    // 設定 GameState 參考以計算放置裝備加成
    _idleIncome.updateGameState(_gameState);
  }

  void _initOfflineModule() {
    _offline.init(
      getIdlePerSec: () => _idleIncome.currentIdlePerSec,
      getGameState: () => _gameState,
      onPersist: (updated) async {
        if (!mounted) return;
        setState(() {
          _gameState = updated;
        });
        if (!widget.testMode) {
          await _saveGameState();
        }
      },
      onPendingReward: (reward, effective) {
        _showOfflineRewardDialog(reward: reward, effective: effective);
      },
    );
  }

  Future<void> _claimOfflineReward() async {
    final pending = _gameState.offline.pendingReward;
    if (pending <= 0) return;
    setState(() {
      _gameState = _gameState.copyWith(
        memePoints: DecimalUtils.add(_gameState.memePoints, pending),
        offline: _gameState.offline.copyWith(pendingReward: 0.0),
      );
    });
    if (!widget.testMode) {
      await _saveGameState();
    }
  }

  void _showOfflineRewardDialog({required double reward, required Duration effective}) {
    // 若已顯示或 reward 無效，略過
    if (reward <= 0) return;
    final title = _localization.getString('offline.title', defaultValue: 'Offline Reward');
    final confirm = _localization.getString('offline.confirm', defaultValue: 'Claim');

    String _formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    final timeStr = _formatDuration(effective);
    final pointsStr = reward.toStringAsFixed(0);
    final messageTemplate = _localization.getString('offline.message', defaultValue: 'You were away {time}, earned ≈ {points}');
    final message = messageTemplate
        .replaceAll('{time}', timeStr)
        .replaceAll('{points}', pointsStr);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xCC110022),
                  Color(0xCC2B0A56),
                ],
              ),
              border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
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
                        color: const Color(0xFF00FFD1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00FFD1), width: 1),
                      ),
                      child: const Icon(Icons.timer, color: Color(0xFF00FFD1)),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 強調點數
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.yellow, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            pointsStr,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.yellow,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _localization.getCommon('memePoints'),
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.yellowAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 補充描述（沿用原 message 模板）
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 160,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B0A56),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF00FFD1), width: 2),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _claimOfflineReward();
                      },
                      child: Text(
                        confirm,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startAutoSaveTimer() {
    if (widget.testMode) {
      // 測試模式：不啟動任何週期性計時器，避免測試一直不閒置
      return;
    }
    // 每 10 秒自動存檔一次，平衡效能與即時性
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveGameState();
    });
    
    // 每秒更新 UI 顯示，讓使用者看到即時變化
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // 觸發 UI 重建，更新顯示的 memePoints
      });
    });
  }

  Future<void> _saveGameState() async {
    if (widget.testMode) {
      // 測試模式：不進行任何持久化
      return;
    }
    try {
      // 直接存檔當前 GameState，不需要合併 IdleIncome
      await _saveService.save(_gameState);
    } catch (e) {
      print('Failed to save game state: $e');
    }
  }

  Future<void> _resetAllState() async {
    // 重置服務統計
    _tapService.reset();
    _idleIncome.resetStats();

    // 重置遊戲狀態（含每日上限區塊與資源）
    setState(() {
      _gameState = GameState(
        saveVersion: _saveService.currentVersion,
        memePoints: 0.0,
        equipments: {},
        lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
        dailyTap: null,
      );
      // 同步清空本地暫存顯示/收益
      _accumulatedIdleIncome = 0.0;
      _lastTapDisplayValue = 0.0;
    });

    // 重置後更新 IdleIncomeService 的 GameState 參考，確保加成立即生效為 0
    _idleIncome.updateGameState(_gameState);

    // 立即存檔
    await _saveGameState();
  }

  void _onEquipmentUpgrade(String id) {
    setState(() {
      _gameState = _equipment.upgrade(_gameState, id);
    });
  }

  void _onIdleEquipmentUpgrade(String id) {
    setState(() {
      _gameState = _equipment.upgradeIdle(_gameState, id);
      // 更新 IdleIncomeService 的 GameState 參考以重新計算加成
      _idleIncome.updateGameState(_gameState);
    });
  }

  void _onCharacterTap() {
    final gained = _tapService.tryTap();
    // 套用每日上限（即使 gained==0 也維持 UI 動效由 MainScreen 播放）
    if (gained >= 0) {
      // 若通過冷卻（gained>0），以裝備加成覆寫實際得分
      final effectiveGain = gained > 0 ? _equipment.computeTapGain(_gameState) : 0.0;
      _lastTapDisplayValue = effectiveGain.toDouble();
      final result = _dailyTap.applyTap(_gameState, effectiveGain);
      if (result.allowedGain > 0) {
        setState(() {
          _gameState = result.state.copyWith(
            memePoints: DecimalUtils.add(result.state.memePoints, result.allowedGain),
          );
        });
      } else {
        // 僅更新狀態以確保 dailyTap block 初始化/維持
        setState(() {
          _gameState = result.state;
        });
      }
    }
  }

  int _onCharacterTapWithResult() {
    final gained = _tapService.tryTap();
    if (gained <= 0) {
      // 冷卻中或無效點擊
      final ensured = _dailyTap.ensureDailyBlock(_gameState);
      if (!identical(ensured, _gameState)) {
        setState(() => _gameState = ensured);
      }
      _lastTapDisplayValue = 0.0;
      return 0;
    }

    // 通過冷卻，以裝備加成覆寫實際得分
    final effectiveGain = _equipment.computeTapGain(_gameState);
    _lastTapDisplayValue = effectiveGain.toDouble();
    final result = _dailyTap.applyTap(_gameState, effectiveGain);
    if (result.allowedGain > 0) {
      setState(() {
        _gameState = result.state.copyWith(
          memePoints: DecimalUtils.add(result.state.memePoints, result.allowedGain),
        );
      });
      return result.allowedGain.floor();
    } else {
      // 已達每日上限：更新狀態但不加分
      setState(() {
        _gameState = result.state;
      });
      return 0;
    }
  }

  Future<void> _fakeAdDoubleToday() async {
    // 假流程：3 秒等待後啟用翻倍
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _gameState = _dailyTap.setAdDoubled(_gameState, enabled: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 測試模式：避免渲染含 Ticker 的 MainScreen，以免 pumpAndSettle 超時
    if (widget.testMode) {
      return const Scaffold(
        body: SizedBox.shrink(),
      );
    }

    // 計算今日上限資訊（僅非測試模式顯示完整 UI）
    final stateWithDaily = _dailyTap.ensureDailyBlock(_gameState);
    final stats = _dailyTap.getStats(stateWithDaily);

    return Scaffold(
      body: Stack(
        children: [
          MainScreen(
            memePoints: _gameState.memePoints,
            equipments: _gameState.equipments,
            onCharacterTap: _onCharacterTap,
            onCharacterTapWithResult: _onCharacterTapWithResult,
            dailyCapTodayGained: stats['todayGained'] as int,
            dailyCapEffective: stats['effectiveCap'] as int,
            adDoubledToday: stats['adDoubledToday'] as bool,
            onAdDouble: _fakeAdDoubleToday,
            onEquipmentUpgrade: _onEquipmentUpgrade,
            onIdleEquipmentUpgrade: _onIdleEquipmentUpgrade,
            onToggleDebug: () => setState(() => _showDebugPanel = !_showDebugPanel),
            lastTapDisplayValue: _lastTapDisplayValue,
            displayMemePoints: DecimalUtils.add(_gameState.memePoints, _accumulatedIdleIncome),
          ),
          if (_showDebugPanel)
            DebugPanel(
              gameState: _gameState,
              tapService: _tapService,
              onResetAll: _resetAllState,
              onOfflineSimulate60s: () async {
                await _offline.simulateAddSeconds(60);
              },
              onOfflineClearPending: () async {
                await _offline.clearPending();
                setState(() {
                  _gameState = _gameState.copyWith();
                });
              },
            ),
        ],
      ),
    );
  }
}
