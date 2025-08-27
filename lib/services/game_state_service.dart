import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import 'secure_save_service.dart';

/// A service to manage the global game state.
/// It handles loading, saving, and notifying listeners of state changes.
class GameStateService {
  static final GameStateService _instance = GameStateService._internal();
  factory GameStateService() => _instance;
  GameStateService._internal();

  final SecureSaveService _saveService = SecureSaveService();

  late ValueNotifier<GameState> gameState;
  bool _initialized = false;
  bool _testMode = false;

  /// Initializes the service by loading the game state from secure storage.
  Future<void> initialize() async {
    if (_initialized) return;

    final loadedState = await _saveService.load();
    gameState = ValueNotifier(loadedState);
    _initialized = true;
  }

  /// Updates the game state and saves it to secure storage.
  /// This will also notify any listeners.
  Future<void> updateGameState(GameState newState) async {
    if (!_initialized) await initialize();
    gameState.value = newState;
    // 在測試模式下避免觸發平台相依的 secure storage
    if (!_testMode) {
      await _saveService.save(newState);
    }
  }

  /// Initializes the service for testing purposes with a specific initial state.
  Future<void> initializeForTest(GameState initialState) async {
    gameState = ValueNotifier(initialState);
    _initialized = true;
    _testMode = true;
  }
}
