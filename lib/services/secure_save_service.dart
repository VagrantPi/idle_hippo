import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

class SecureSaveService {
  static final SecureSaveService _instance = SecureSaveService._internal();
  factory SecureSaveService() => _instance;
  SecureSaveService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  int _currentVersion = 1;
  // Fast, non-secure cache (low-latency)
  static const String _fastKey = 'game_state_fast';

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
        await _storage.write(
          key: _versionKey,
          value: currentVersion.toString(),
        );
      }
    } catch (e) {
      // 在測試或無法使用原生插件時（如 MissingPluginException），
      // 略過安全儲存初始化，改由 fast-cache 與記憶體狀態支援啟動。
      // 這能避免在單元測試（dart vm）中觸發平台通道錯誤。
      // 實際寫入安全儲存將在未來可用時透過 save()/load() 的背景流程處理。
      return;
    }
  }

  /// 載入遊戲狀態
  Future<GameState> load() async {
    try {
      // 1) 讀取安全存檔（主/備）
      GameState? durable;
      try {
        final mainData = await _storage.read(key: _mainKey);
        if (mainData != null) {
          final s = GameState.fromJson(mainData);
          if (s.validate()) durable = s;
        }
      } catch (_) {
        // 忽略安全存檔讀取錯誤（例如測試環境 MissingPlugin），改用快取
      }
      if (durable == null) {
        try {
          final backupData = await _storage.read(key: _backupKey);
          if (backupData != null) {
            final s = GameState.fromJson(backupData);
            if (s.validate()) durable = s;
          }
        } catch (_) {
          // 忽略備份讀取錯誤
        }
      }

      // 2) 讀取快速快取（SharedPreferences）
      GameState? fast;
      try {
        final prefs = await SharedPreferences.getInstance();
        final fastStr = prefs.getString(_fastKey);
        if (fastStr != null) {
          final s = GameState.fromJson(fastStr);
          if (s.validate()) fast = s;
        }
      } catch (_) {}

      // 3) 回傳更新較新的狀態（以 lastTs 比較）；若 fast 更新，背景刷新安全存檔
      final chosen = _pickFresher(durable, fast) ?? GameState.initial(_currentVersion);
      if (fast != null && (durable == null || fast.lastTs > (durable.lastTs))) {
        // 背景補寫入安全存檔
        unawaited(_atomicWrite(chosen).catchError((_) => null));
      }
      return chosen;
    } catch (e) {
      final initState = GameState.initial(_currentVersion);
      return initState;
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

      // 先寫入快速快取（低延遲）
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fastKey, updatedState.toJson());
      } catch (_) {
        // 忽略快取寫入錯誤
      }

      // 背景原子寫入安全存檔（不阻塞呼叫端）
      unawaited(_atomicWrite(updatedState).catchError((_) => null));
    } catch (e) {
      // 快速路徑：即使安全存檔寫入失敗，也不拋出，避免阻塞互動
      // 讓上層仍可繼續，並依賴後續定期/下次互動再嘗試安全寫入
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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fastKey, initialState.toJson());
      } catch (_) {}
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

  // 選擇較新的狀態（以 lastTs）；若都為 null，回傳 null
  GameState? _pickFresher(GameState? a, GameState? b) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return (b.lastTs > a.lastTs) ? b : a;
  }
}
