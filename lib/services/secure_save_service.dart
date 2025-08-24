import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/game_state.dart';

class SecureSaveService {
  static final SecureSaveService _instance = SecureSaveService._internal();
  factory SecureSaveService() => _instance;
  SecureSaveService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  int _currentVersion = 1;
  
  // Key 命名常數
  static const String _versionKey = 'save_version';
  String get _mainKey => 'game_state_v$_currentVersion';
  String get _backupKey => '${_mainKey}_bak';

  /// 初始化服務
  Future<void> init({required int currentVersion}) async {
    _currentVersion = currentVersion;
    
    try {
      // 讀取存檔版本
      final storedVersionStr = await _storage.read(key: _versionKey);
      if (storedVersionStr != null) {
        final storedVersion = int.parse(storedVersionStr);
        
        if (storedVersion < currentVersion) {
          // 需要遷移
          await migrateIfNeeded(storedVersion, currentVersion);
        } else if (storedVersion > currentVersion) {
          // 版本過新，回退初始狀態並保留原始資料
          await _backupCurrentData();
          await _setInitialState();
        }
      } else {
        // 首次啟動，設定版本
        await _storage.write(key: _versionKey, value: currentVersion.toString());
      }
    } catch (e) {
      await _setInitialState();
    }
  }

  /// 載入遊戲狀態
  Future<GameState> load() async {
    try {
      // 嘗試讀取主要存檔
      final mainData = await _storage.read(key: _mainKey);
      if (mainData != null) {
        final state = GameState.fromJson(mainData);
        if (state.validate()) {
          return state;
        }
      }

      // 主要存檔失敗，嘗試備份
      final backupData = await _storage.read(key: _backupKey);
      if (backupData != null) {
        final state = GameState.fromJson(backupData);
        if (state.validate()) {
          // 立即將備份寫回主要存檔
          await _atomicWrite(state);
          return state;
        }
      }

      // 所有存檔都失敗，回傳初始狀態
      return GameState.initial(_currentVersion);
    } catch (e) {
      return GameState.initial(_currentVersion);
    }
  }

  /// 保存遊戲狀態
  Future<void> save(GameState state) async {
    try {
      // 驗證狀態
      if (!state.validate()) {
        throw Exception('Invalid game state, cannot save');
      }

      // 更新時間戳
      final updatedState = state.updateTimestamp();
      
      // 原子寫入
      await _atomicWrite(updatedState);
    } catch (e) {
      rethrow;
    }
  }

  /// 原子寫入保護
  Future<void> _atomicWrite(GameState state) async {
    try {
      // 1. 先讀取現有主要存檔作為備份
      final currentMain = await _storage.read(key: _mainKey);
      if (currentMain != null) {
        await _storage.write(key: _backupKey, value: currentMain);
      }

      // 2. 寫入新的主要存檔
      final jsonData = state.toJson();
      await _storage.write(key: _mainKey, value: jsonData);

      // 3. 立即驗證寫入結果
      final verifyData = await _storage.read(key: _mainKey);
      if (verifyData == null) {
        throw Exception('Write verification failed: data is null');
      }

      final verifyState = GameState.fromJson(verifyData);
      if (!verifyState.validate()) {
        throw Exception('Write verification failed: invalid state');
      }

      // 4. 更新版本資訊
      await _storage.write(key: _versionKey, value: _currentVersion.toString());
      
    } catch (e) {
      await _recoverFromBackup();
      rethrow;
    }
  }

  /// 從備份恢復
  Future<void> _recoverFromBackup() async {
    try {
      final backupData = await _storage.read(key: _backupKey);
      if (backupData != null) {
        await _storage.write(key: _mainKey, value: backupData);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 重置存檔（雙重確認）
  Future<void> resetWithDoubleConfirm({
    required String confirmA,
    required String confirmB,
  }) async {
    if (confirmA != "RESET" || confirmB != "RESET") {
      throw Exception('Reset confirmation failed');
    }

    try {
      // 清除所有相關 Key
      await _storage.delete(key: _mainKey);
      await _storage.delete(key: _backupKey);
      await _storage.delete(key: _versionKey);
      
      // 清除其他版本的存檔
      for (int version = 1; version <= _currentVersion + 1; version++) {
        await _storage.delete(key: 'game_state_v$version');
        await _storage.delete(key: 'game_state_v${version}_bak');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 版本遷移
  Future<void> migrateIfNeeded(int fromVersion, int toVersion) async {
    try {
      for (int version = fromVersion; version < toVersion; version++) {
        await _migrateVersion(version, version + 1);
      }
      
      // 更新版本號
      await _storage.write(key: _versionKey, value: toVersion.toString());
    } catch (e) {
      rethrow;
    }
  }

  /// 單一版本遷移
  Future<void> _migrateVersion(int from, int to) async {
    // 讀取舊版本資料
    final oldKey = 'game_state_v$from';
    final oldData = await _storage.read(key: oldKey);
    
    if (oldData == null) {
      return;
    }

    try {
      final oldState = GameState.fromJson(oldData);
      
      // 執行版本特定的遷移邏輯
      GameState newState;
      switch (to) {
        case 2:
          newState = _migrateToV2(oldState);
          break;
        case 3:
          newState = _migrateToV3(oldState);
          break;
        default:
          // 預設遷移：只更新版本號
          newState = oldState.copyWith(saveVersion: to);
      }

      // 驗證並保存新狀態
      if (!newState.validate()) {
        throw Exception('Migration validation failed for v$to');
      }

      final newKey = 'game_state_v$to';
      await _storage.write(key: newKey, value: newState.toJson());
      
    } catch (e) {
      rethrow;
    }
  }

  /// 遷移到版本 2 的邏輯
  GameState _migrateToV2(GameState oldState) {
    // 範例：版本 2 可能新增了某些欄位或改變了資料結構
    return oldState.copyWith(
      saveVersion: 2,
      // 這裡可以加入版本 2 特有的遷移邏輯
    );
  }

  /// 遷移到版本 3 的邏輯
  GameState _migrateToV3(GameState oldState) {
    // 範例：版本 3 的遷移邏輯
    return oldState.copyWith(
      saveVersion: 3,
      // 這裡可以加入版本 3 特有的遷移邏輯
    );
  }

  /// 備份當前資料
  Future<void> _backupCurrentData() async {
    try {
      final currentData = await _storage.read(key: _mainKey);
      if (currentData != null) {
        await _storage.write(key: '${_mainKey}_legacy', value: currentData);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 設定初始狀態
  Future<void> _setInitialState() async {
    try {
      final initialState = GameState.initial(_currentVersion);
      await _storage.write(key: _mainKey, value: initialState.toJson());
      await _storage.write(key: _versionKey, value: _currentVersion.toString());
    } catch (e) {
      rethrow;
    }
  }

  /// 驗證遊戲狀態
  bool validate(GameState state) {
    return state.validate();
  }

  /// 取得當前版本
  int get currentVersion => _currentVersion;
}
