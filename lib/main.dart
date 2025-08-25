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
import 'package:idle_hippo/services/daily_mission_service.dart';
import 'package:idle_hippo/services/main_quest_service.dart';
import 'package:idle_hippo/services/pet_ticket_quest_service.dart';
import 'package:idle_hippo/ui/main_screen.dart';
import 'package:idle_hippo/ui/debug_panel.dart';
import 'package:idle_hippo/services/decimal_utils.dart';
import 'package:idle_hippo/ui/components/slide_in_dialog.dart';

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
  final DailyMissionService _dailyMission = DailyMissionService();
  final MainQuestService _mainQuest = MainQuestService();
  final PetTicketQuestService _petTicketQuest = PetTicketQuestService();

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
    _initDailyMissionModule();
    _initMainQuestModule();
    _initPetTicketQuestModule();
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
      // 初始值可由設定檔控制是否顯示 DebugPanel
      final initialShow = _configService.getValue('game.ui.showDebugPanel', defaultValue: false);
      if (mounted && initialShow is bool) {
        setState(() {
          _showDebugPanel = initialShow;
        });
      }
    } catch (e) {
      throw Exception('Failed to load config: $e');
    }
  }

  Future<void> _initializeLocalization() async {
    try {
      await _localization.init(language: 'zh'); // 預設使用繁體中文
    } catch (e) {
      throw Exception('Failed to initialize localization: $e');
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
      } catch (e) {
        throw Exception('Failed to load game state: $e');
      }
    }
    
    // 統一在這裡初始化放置收益系統
    _idleIncome.init(onIncomeGenerated: (double points) {
      if (!mounted) return;
      final pointsToAdd = points;
      if (pointsToAdd > 0) {
        _accumulatedIdleIncome = DecimalUtils.add(_accumulatedIdleIncome, pointsToAdd);
        
        // 處理每日任務進度（資源獲得）
        GameState updatedState = _dailyMission.onEarnPoints(_gameState, pointsToAdd);
        
        // 處理主線任務進度（點數獲得）
        updatedState = _mainQuest.onEarnPoints(updatedState, pointsToAdd);

        // 處理寵物抽獎券任務進度
        updatedState = _petTicketQuest.addProgress(updatedState, pointsToAdd);
        
        setState(() {
          _gameState = updatedState.copyWith(
            memePoints: DecimalUtils.add(updatedState.memePoints, pointsToAdd),
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
      onOfflineReward: (reward, effective, {required bool canDouble}) {
        // 將離線獎勵納入每日任務的累積進度（不重複加分，只更新任務狀態）
        if (reward > 0) {
          if (mounted) {
            setState(() {
              GameState updatedState = _dailyMission.onEarnPoints(_gameState, reward);
              updatedState = _mainQuest.onEarnPoints(updatedState, reward);
              // 同步推進寵物抽獎券任務進度（離線收益）
              updatedState = _petTicketQuest.addProgress(updatedState, reward);
              _gameState = updatedState;
            });
          }
        }
        _showOfflineRewardDialog(
          reward: reward,
          effective: effective,
          canDouble: canDouble,
        );
      },
      onOfflineDoubled: (amount) {
        if (!mounted) return;
        // 翻倍加發的獎勵同樣計入每日任務的累積進度
        if (amount > 0) {
          setState(() {
            GameState updatedState = _dailyMission.onEarnPoints(_gameState, amount);
            updatedState = _mainQuest.onEarnPoints(updatedState, amount);
            // 同步推進寵物抽獎券任務進度（離線翻倍）
            updatedState = _petTicketQuest.addProgress(updatedState, amount);
            _gameState = updatedState;
          });
        }
        final title = _localization.getString('offline.doubled_success', defaultValue: 'Reward Doubled!');
        final confirm = _localization.getOffline('confirm');
        final points = amount.toStringAsFixed(0);

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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.yellow, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '+$points',
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
                      ),
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
                                confirm,
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
      },
    );
  }

  void _initDailyMissionModule() {
    // 設定獎勵回調
    _dailyMission.setRewardCallback((points) {
      if (!mounted) return;
      setState(() {
        _gameState = _gameState.copyWith(
          memePoints: DecimalUtils.add(_gameState.memePoints, points),
        );
      });
    });

    // 確保每日任務區塊初始化
    setState(() {
      _gameState = _dailyMission.ensureDailyMissionBlock(_gameState);
    });
  }

  void _initMainQuestModule() {
    // 設定任務完成回調
    _mainQuest.setQuestCompletedCallback((questId, rewardType, rewardId) {
      if (!mounted) return;

      print('questId: $questId, rewardType: $rewardType, rewardId: $rewardId'); 
      // 顯示任務完成彈窗
      _showQuestCompletedDialog(questId, rewardType, rewardId);
    });

    // 確保主線任務狀態初始化
    setState(() {
      _gameState = _mainQuest.ensureMainQuestState(_gameState);
    });
  }

  void _initPetTicketQuestModule() {
    // 檢查並解鎖寵物抽獎券任務（當主線達到指定階段）
    GameState updatedState = _petTicketQuest.checkAndUnlock(_gameState);

    // 若已解鎖但尚未有任務目標，依目前 idlePerSec 產生第一個任務
    final quest = updatedState.petTicketQuest;
    if (quest != null && quest.available && quest.target <= 0.0) {
      final currentIdlePerSec = _idleIncome.currentIdlePerSec;
      updatedState = _petTicketQuest.generateFirstQuest(
        updatedState,
        currentIdlePerSec: currentIdlePerSec,
      );
    }

    if (!identical(updatedState, _gameState)) {
      setState(() {
        _gameState = updatedState;
      });
    }
  }

  void _showQuestCompletedDialog(String questId, String rewardType, String rewardId) {
    final title = _localization.getString('quest.completed.title', defaultValue: '任務完成！');
    final confirm = _localization.getString('quest.completed.confirm', defaultValue: '確認');
    
    // 根據 questId 獲取任務標題
    final questTitle = _localization.getString('quest.$questId.title', defaultValue: questId);
    
    print('questId: $questId | rewardType: $rewardType | rewardId: $rewardId');
    // 根據獎勵類型生成獎勵描述
    String rewardDescription;
    switch (rewardType) {
      case 'equipment':
        final equipmentName =_localization.getString('equip.$rewardId.name', defaultValue: '特殊');
        rewardDescription = _localization.getString('quest.reward.equipment', 
            defaultValue: '解鎖特殊裝備！');
        rewardDescription = rewardDescription.replaceFirst('{rewardId}', equipmentName);
        break;
      case 'system':
        if (rewardId == 'title') {
          rewardDescription = _localization.getString('quest.reward.title_system', 
              defaultValue: '解鎖稱號系統！');
        } else if (rewardId == 'pet') {
          rewardDescription = _localization.getString('quest.reward.pet_system', 
              defaultValue: '解鎖寵物系統！');
        } else {
          rewardDescription = _localization.getString('quest.reward.system', 
              defaultValue: '解鎖 $rewardId 系統！');
        }
        break;
      case 'hippo':
        rewardDescription = _localization.getString('quest.reward.skin', 
            defaultValue: '解鎖新造型：$rewardId！');
        break;
      default:
        rewardDescription = _localization.getString('quest.reward.unknown', 
            defaultValue: '獲得神秘獎勵！');
    }
    print('rewardDescription: $rewardDescription');

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
                    Color(0xCC220011),
                    Color(0xCCE89A00),
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
                        child: const Icon(Icons.emoji_events, color: Color(0xFF00FFD1)),
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
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '完成【$questTitle】',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rewardDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.yellow,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE89A00),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF00FFD1), width: 2),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            confirm,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.black,
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

  void _showOfflineRewardDialog({
    required double reward,
    required Duration effective,
    required bool canDouble,
  }) {
    // 若已顯示或 reward 無效，略過
    if (reward <= 0) return;
    final title = _localization.getString('offline.title', defaultValue: 'Offline Reward');
    final confirm = _localization.getString('offline.confirm', defaultValue: 'Claim');

    String formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    final timeStr = formatDuration(effective);
    final pointsStr = reward.toStringAsFixed(0);
    final messageTemplate = _localization.getString('offline.message', defaultValue: 'You were away {time}, earned ≈ {points}');
    final message = messageTemplate
        .replaceAll('{time}', timeStr)
        .replaceAll('{points}', pointsStr);

    showTopSlideDialog(
      context,
      barrierDismissible: false,
      child: Builder(
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
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
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canDouble)
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.slow_motion_video, size: 20),
                          label: Text(_localization.getString('offline.double_reward', defaultValue: 'Double x2')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE89A00),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _offline.claimOfflineAdDouble();
                          },
                        ),
                      ),
                    if (canDouble) const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
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
                        onPressed: () {
                          Navigator.of(ctx).pop();
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
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
      rethrow;
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
    if (gained <= 0) {
      // 冷卻中：確保 dailyTap block 初始化但不加分
      final ensured = _dailyTap.ensureDailyBlock(_gameState);
      if (!identical(ensured, _gameState)) {
        setState(() => _gameState = ensured);
      }
      return;
    }
    // 通過冷卻，以裝備加成覆寫實際得分
    final effectiveGain = _equipment.computeTapGain(_gameState);
    final result = _dailyTap.applyTap(_gameState, effectiveGain);
    
    // 處理每日任務進度（有效點擊）
    GameState updatedState = result.state;
    updatedState = _dailyMission.onValidTap(updatedState);
    
    // 處理主線任務進度（點擊計數）
    updatedState = _mainQuest.onTap(updatedState);
    
    if (result.allowedGain > 0) {
      // 累積任務僅由被動來源推進：此處不再計入 onEarnPoints
      setState(() {
        _gameState = updatedState.copyWith(
          memePoints: DecimalUtils.add(updatedState.memePoints, result.allowedGain),
        );
      });
    } else {
      // 僅更新狀態以確保 dailyTap block 初始化/維持
      setState(() {
        _gameState = updatedState;
      });
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
    // 先處理每日任務：有效點擊計數
    GameState updatedState = result.state;
    updatedState = _dailyMission.onValidTap(updatedState);
    
    // 處理主線任務進度（點擊計數）
    updatedState = _mainQuest.onTap(updatedState);

    if (result.allowedGain > 0) {
      // 累積任務僅由被動來源推進：此處不再計入 onEarnPoints
      setState(() {
        _gameState = updatedState.copyWith(
          memePoints: DecimalUtils.add(updatedState.memePoints, result.allowedGain),
        );
      });
      return result.allowedGain.floor();
    } else {
      // 已達每日上限：僅更新狀態（保留任務可能的變更）
      setState(() {
        _gameState = updatedState;
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
    
    // 獲取每日任務資訊
    final missionParams = _dailyMission.getDisplayParams(_gameState);
    final missionPlan = _dailyMission.getTodayPlan(_gameState);
    final missionStats = _dailyMission.getStats(_gameState);

    return Scaffold(
      body: Stack(
        children: [
          MainScreen(
            memePoints: _gameState.memePoints,
            equipments: _gameState.equipments,
            onCharacterTap: _onCharacterTap,
            gameState: _gameState,
            onCharacterTapWithResult: _onCharacterTapWithResult,
            dailyCapTodayGained: stats['todayGained'] as int,
            dailyCapEffective: stats['effectiveCap'] as int,
            adDoubledToday: stats['adDoubledToday'] as bool,
            onAdDouble: _fakeAdDoubleToday,
            onEquipmentUpgrade: _onEquipmentUpgrade,
            onIdleEquipmentUpgrade: _onIdleEquipmentUpgrade,
            onToggleDebug: () => setState(() => _showDebugPanel = !_showDebugPanel),
            lastTapDisplayValue: _lastTapDisplayValue,
            displayMemePoints: _gameState.memePoints,
            // 每日任務參數
            missionType: missionParams['type'] as String?,
            missionProgress: missionParams['progress'] as int?,
            missionTarget: missionParams['target'] as int?,
            missionPoints: missionParams['points'] as int?,
            onMissionTap: () {
              // 點擊每日任務條：嘗試推進 tap 類型任務進度
              setState(() {
                _gameState = _dailyMission.onValidTap(_gameState);
              });
            },
            missionPlan: missionPlan,
            missionsTodayCompleted: missionStats['todayCompleted'] as int,
            onClaimCurrentMission: () {
              // 計算即將領取的獎勵（以當前任務 index 為準）
              final currentIndex = _gameState.dailyMission?.index ?? 1;
              final reward = _dailyMission.getRewardForIndex(currentIndex).toInt();
              // 領取並推進任務
              setState(() {
                _gameState = _dailyMission.claimIfReady(_gameState);
              });
              // 顯示領取彈窗
              final pointsStr = reward.toString();
              final title = _localization.getString('mission.dailyMissions', defaultValue: '每日任務');
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
                              Color(0xCC112200),
                              Color(0xCCE89A00),
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
                                  child: const Icon(Icons.card_giftcard, color: Color(0xFF00FFD1)),
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
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.yellow, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+$pointsStr',
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
              // 可選：非測試模式下立即存檔
              _saveGameState();
            },
            onClaimCurrentStage: () {
              // 主線任務領取並推進到下一階段，包含更新 unlockedRewards
              setState(() {
                _gameState = _mainQuest.claimCurrentQuest(_gameState);
              });
              // 立刻檢查並初始化寵物抽獎券任務（在進入 Stage 4 後）
              _initPetTicketQuestModule();
              // 同步 IdleIncome 的 GameState 參考，確保加成與任務累積即時生效
              _idleIncome.updateGameState(_gameState);
              _saveGameState();
            },
            onPetTicketClaim: (withAd) {
              setState(() {
                _gameState = _petTicketQuest.claimReward(
                  _gameState,
                  withAd: withAd,
                  currentIdlePerSec: _idleIncome.currentIdlePerSec,
                );
                _idleIncome.updateGameState(_gameState);
              });
              _saveGameState();
            },
          ),
          if (_showDebugPanel)
            DebugPanel(
              gameState: _gameState,
              tapService: _tapService,
              dailyMissionService: _dailyMission,
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
              onForceCompleteMission: () {
                setState(() {
                  _gameState = _dailyMission.forceCompleteMission(_gameState);
                });
              },
              onSimulateDayReset: () {
                setState(() {
                  _gameState = _dailyMission.simulateDayReset(_gameState);
                });
              },
            ),
        ],
      ),
    );
  }
}
