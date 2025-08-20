import 'dart:async';
import 'package:flutter/material.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/game_clock_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';
import 'package:idle_hippo/services/secure_save_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
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

  void _onCharacterTap() {
    final tapValue = (_configService.getValue('game.tap.base', defaultValue: 1) as num).toInt();
    setState(() {
      _gameState = _gameState.copyWith(
        memePoints: _gameState.memePoints + tapValue,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDebugPanel = _configService.getValue('game.ui.showDebugPanel', defaultValue: false);
    
    return Scaffold(
      body: Stack(
        children: [
          MainScreen(
            memePoints: _gameState.memePoints,
            onCharacterTap: _onCharacterTap,
          ),
          if (showDebugPanel)
            DebugPanel(
              gameState: _gameState,
            ),
        ],
      ),
    );
  }
}
