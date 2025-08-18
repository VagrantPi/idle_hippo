import 'package:flutter/material.dart';
import 'dart:async';
import 'services/config_service.dart';
import 'services/secure_save_service.dart';
import 'models/game_state.dart';
import 'ui/debug_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 只在非測試環境中初始化配置服務
  if (!_isTestEnvironment()) {
    final configService = ConfigService();
    await configService.loadConfig();
    
    // 初始化存檔服務
    final saveService = SecureSaveService();
    await saveService.init(currentVersion: 1);
  }
  
  runApp(const IdleHippoApp());
}

bool _isTestEnvironment() {
  // 檢查是否在測試環境中運行
  return const bool.fromEnvironment('flutter.inspector.structuredErrors', defaultValue: false);
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
  
  GameState _gameState = GameState.initial(1);
  bool _showDebugPanel = true;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _initializeFromConfig();
    _loadGameState();
    _startAutoSaveTimer();
  }

  void _startAutoSaveTimer() {
    // 每分鐘自動存檔一次，確保 lastTs 保持更新
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _saveGameState();
    });
  }

  @override
  void dispose() {
    print('Disposing _IdleHippoScreenState');
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _initializeFromConfig() {
    if (_configService.isLoaded) {
      // 檢查是否顯示 debug 面板
      final showDebug = _configService.getValue('game.ui.showDebugPanel', defaultValue: true);
      setState(() {
        _showDebugPanel = showDebug;
      });
    }
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
  }

  Future<void> _saveGameState() async {
    try {
      // 更新時間戳再存檔
      final updatedState = _gameState.updateTimestamp();
      setState(() {
        _gameState = updatedState;
      });
      
      await _saveService.save(_gameState);
      print('Game state saved successfully');
    } catch (e) {
      print('Failed to save game state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('存檔失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onTap() {
    final tapValue = _configService.getValue('game.tap.base', defaultValue: 1);
    setState(() {
      _gameState = _gameState.copyWith(
        memePoints: _gameState.memePoints + (tapValue as num).toInt(),
      );
    });
    
    // 自動存檔
    _saveGameState();
  }

  void _toggleDebugPanel() {
    setState(() {
      _showDebugPanel = !_showDebugPanel;
    });
  }

  Future<void> _resetGame() async {
    final confirmed = await _showResetConfirmDialog();
    if (confirmed == true) {
      try {
        await _saveService.resetWithDoubleConfirm(
          confirmA: "RESET",
          confirmB: "RESET",
        );
        
        setState(() {
          _gameState = GameState.initial(1);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('遊戲已重置'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('重置失敗: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showResetConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認重置'),
          content: const Text('確定要重置所有遊戲進度嗎？此操作無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('確認重置'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[50],
      body: Stack(
        children: [
          // 主要內容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game Title
                Text(
                  'Idle Hippo',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 60),
                // Meme Points Display
                GestureDetector(
                  onTap: _onTap,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_gameState.memePoints}',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Meme Points',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to earn!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Game Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_configService.isLoaded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Config Loaded ✓',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Save v${_gameState.saveVersion}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Reset Button
                ElevatedButton(
                  onPressed: _resetGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[700],
                  ),
                  child: const Text('重置遊戲'),
                ),
              ],
            ),
          ),
          // Debug Toggle Button
          DebugToggleButton(onToggle: _toggleDebugPanel),
          // Debug Panel
          if (_showDebugPanel) DebugPanel(gameState: _gameState),
        ],
      ),
    );
  }
}
