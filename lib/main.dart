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
import 'package:idle_hippo/ui/main_screen.dart';
import 'package:idle_hippo/ui/debug_panel.dart';

void main() {
  runApp(const IdleHippoApp());
}

class IdleHippoApp extends StatelessWidget {
  const IdleHippoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Hippo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const IdleHippoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IdleHippoScreen extends StatefulWidget {
  const IdleHippoScreen({super.key});

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

  late GameState _gameState;
  Timer? _autoSaveTimer;
  Timer? _uiUpdateTimer;

  // 累積的放置收益（使用 double 避免小數被截斷）
  double _accumulatedIdleIncome = 0.0;

  @override
  void initState() {
    super.initState();
    _gameState = GameState.initial(_saveService.currentVersion);
    _initializeGame();
    _startAutoSaveTimer();
  }

  Future<void> _initializeGame() async {
    await _initializeFromConfig();
    await _initializeLocalization();
    await _loadGameState();
    
    // 確保 IdleIncome 初始化完成後再啟動時間系統
    _gameClock.start();
  }

  Future<void> _initializeFromConfig() async {
    try {
      await _configService.loadConfig();
      print('Config loaded successfully');
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
    _gameClock.dispose();
    _idleIncome.dispose();
    super.dispose();
  }

  Future<void> _loadGameState() async {
    try {
      final loadedState = await _saveService.load();
      setState(() {
        _gameState = loadedState;
      });
      
      print('Game state loaded: ${_gameState.memePoints} meme points');
    } catch (e) {
      print('Failed to load game state: $e');
    }
    
    // 統一在這裡初始化放置收益系統
    _idleIncome.init(onIncomeGenerated: (double points) {
      _accumulatedIdleIncome += points;
      
      // 當累積收益 >= 1 時才更新 GameState
      if (_accumulatedIdleIncome >= 1.0) {
        final pointsToAdd = _accumulatedIdleIncome.floor();
        _accumulatedIdleIncome -= pointsToAdd;
        
        setState(() {
          _gameState = _gameState.copyWith(
            memePoints: _gameState.memePoints + pointsToAdd,
          );
        });
      }
    });
  }

  void _startAutoSaveTimer() {
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
        memePoints: 0,
        equipments: {},
        lastTs: DateTime.now().toUtc().millisecondsSinceEpoch,
        dailyTap: null,
      );
    });

    // 立即存檔
    await _saveGameState();
  }

  void _onCharacterTap() {
    final gained = _tapService.tryTap();
    // 套用每日上限（即使 gained==0 也維持 UI 動效由 MainScreen 播放）
    if (gained >= 0) {
      final result = _dailyTap.applyTap(_gameState, gained);
      if (result.allowedGain > 0) {
        setState(() {
          _gameState = result.state.copyWith(
            memePoints: result.state.memePoints + result.allowedGain,
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
      return 0;
    }

    final result = _dailyTap.applyTap(_gameState, gained);
    if (result.allowedGain > 0) {
      setState(() {
        _gameState = result.state.copyWith(
          memePoints: result.state.memePoints + result.allowedGain,
        );
      });
      return result.allowedGain;
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
    final showDebugPanel = _configService.getValue('game.ui.showDebugPanel', defaultValue: false);
    
    // 計算今日上限資訊
    final stateWithDaily = _dailyTap.ensureDailyBlock(_gameState);
    final stats = _dailyTap.getStats(stateWithDaily);

    return Scaffold(
      body: Stack(
        children: [
          MainScreen(
            memePoints: _gameState.memePoints,
            onCharacterTap: _onCharacterTap,
            onCharacterTapWithResult: _onCharacterTapWithResult,
            dailyCapTodayGained: stats['todayGained'] as int,
            dailyCapEffective: stats['effectiveCap'] as int,
            adDoubledToday: stats['adDoubledToday'] as bool,
            onAdDouble: _fakeAdDoubleToday,
          ),
          if (showDebugPanel)
            DebugPanel(
              gameState: _gameState,
              tapService: _tapService,
              onResetAll: _resetAllState,
            ),
        ],
      ),
    );
  }
}
