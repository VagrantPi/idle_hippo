import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StoreService handles purchase counts and simple eligibility checks
/// for store items. Persistence uses SharedPreferences and keeps a
/// simple map: itemKey -> purchasedCount.
class StoreService extends ChangeNotifier {
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  static const String _prefsKey = 'store.purchases';
  static const String _dailyCountsKey = 'store.daily.counts';
  static const String _dailyDateKey = 'store.daily.date';
  static const String _monthlyCountsKey = 'store.monthly.counts';
  static const String _monthlyMonthKey = 'store.monthly.month';
  static const String _installDateKey = 'store.install.date';

  SharedPreferences? _prefs; // cache prefs for sync reads in getters
  Map<String, int> _counts = {};
  bool _loaded = false;
  Map<String, int> _dailyCounts = {};
  String _dailyDate = '';
  Map<String, int> _monthlyCounts = {};
  String _monthlyMonth = '';
  String _installDate = '';

  bool get isLoaded => _loaded;

  /// Loads counts from SharedPreferences once (idempotent).
  Future<void> initialize() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final map = prefs.getStringList(_prefsKey);
      // We store as ["key=count", ...] for simplicity
      if (map != null) {
        final parsed = <String, int>{};
        for (final entry in map) {
          final idx = entry.indexOf('=');
          if (idx <= 0) continue;
          final k = entry.substring(0, idx);
          final vStr = entry.substring(idx + 1);
          final v = int.tryParse(vStr) ?? 0;
          parsed[k] = v;
        }
        _counts = parsed;
      }
      // Load daily counts
      final today = _todayAsiaTaipei();
      _dailyDate = prefs.getString(_dailyDateKey) ?? '';
      final dailyList = prefs.getStringList(_dailyCountsKey);
      if (dailyList != null) {
        final parsedDaily = <String, int>{};
        for (final entry in dailyList) {
          final idx = entry.indexOf('=');
          if (idx <= 0) continue;
          final k = entry.substring(0, idx);
          final vStr = entry.substring(idx + 1);
          final v = int.tryParse(vStr) ?? 0;
          parsedDaily[k] = v;
        }
        _dailyCounts = parsedDaily;
      }
      // Reset if day changed
      if (_dailyDate != today) {
        _dailyDate = today;
        _dailyCounts.clear();
        await _persistDaily();
      }

      // Load monthly counts
      final currentMonth = _monthAsiaTaipei();
      _monthlyMonth = prefs.getString(_monthlyMonthKey) ?? '';
      final monthlyList = prefs.getStringList(_monthlyCountsKey);
      if (monthlyList != null) {
        final parsedMonthly = <String, int>{};
        for (final entry in monthlyList) {
          final idx = entry.indexOf('=');
          if (idx <= 0) continue;
          final k = entry.substring(0, idx);
          final vStr = entry.substring(idx + 1);
          final v = int.tryParse(vStr) ?? 0;
          parsedMonthly[k] = v;
        }
        _monthlyCounts = parsedMonthly;
      }
      if (_monthlyMonth != currentMonth) {
        _monthlyMonth = currentMonth;
        _monthlyCounts.clear();
        await _persistMonthly();
      }

      // Initialize install date if not set
      _installDate = prefs.getString(_installDateKey) ?? '';
      if (_installDate.isEmpty) {
        _installDate = today;
        await prefs.setString(_installDateKey, _installDate);
      }

      _loaded = true;
    } catch (_) {
      // Keep defaults on failure; do not crash UI
      _loaded = true;
    }
  }

  /// Returns current purchased count (0 if not found).
  int getCount(String itemKey) {
    return _counts[itemKey] ?? 0;
  }

  /// Whether a limited item can be purchased given a max count.
  bool canPurchaseLimited(String itemKey, int maxCount) {
    final c = getCount(itemKey);
    return c < maxCount;
  }

  /// Records a purchase for an item and persists.
  Future<void> purchase(String itemKey) async {
    final next = (getCount(itemKey) + 1);
    _counts[itemKey] = next;
    await _persist();
    notifyListeners();
  }

  // Daily window helpers
  String _todayAsiaTaipei() {
    final utcNow = DateTime.now().toUtc();
    final taipei = utcNow.add(const Duration(hours: 8));
    return '${taipei.year.toString().padLeft(4, '0')}-${taipei.month.toString().padLeft(2, '0')}-${taipei.day.toString().padLeft(2, '0')}';
  }

  String _monthAsiaTaipei() {
    final utcNow = DateTime.now().toUtc();
    final taipei = utcNow.add(const Duration(hours: 8));
    return '${taipei.year.toString().padLeft(4, '0')}-${taipei.month.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureDailyWindow() async {
    final today = _todayAsiaTaipei();
    if (_dailyDate != today) {
      _dailyDate = today;
      _dailyCounts.clear();
      await _persistDaily();
    }
  }

  /// Explicitly refresh daily window by reconciling with persisted values.
  /// Useful for tests or app lifecycle hooks when system date may jump.
  Future<void> refreshDailyWindow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final today = _todayAsiaTaipei();
      final stored = prefs.getString(_dailyDateKey) ?? _dailyDate;
      if (stored != today) {
        _dailyDate = today;
        _dailyCounts.clear();
        await _persistDaily();
      }
    } catch (_) {}
  }

  int getDailyCount(String itemKey) {
    // Check persisted date to allow tests to manipulate date and trigger reset.
    final today = _todayAsiaTaipei();
    final storedDate = _prefs?.getString(_dailyDateKey) ?? _dailyDate;
    if (storedDate != today) {
      _dailyDate = today;
      _dailyCounts.clear();
      // Persist asynchronously; do not notify during build.
      _persistDaily();
      return 0;
    }
    return _dailyCounts[itemKey] ?? 0;
  }

  /// Whether a daily-limited item can be purchased today given a max count.
  /// Interpretation: allow while current daily count < maxCount.
  bool canPurchaseDaily(String itemKey, int maxCount) {
    final c = getDailyCount(itemKey);
    return c < maxCount;
  }

  Future<void> purchaseDaily(String itemKey) async {
    await _ensureDailyWindow();
    final next = (getDailyCount(itemKey) + 1);
    _dailyCounts[itemKey] = next;
    await _persistDaily();
    notifyListeners();
  }

  Future<void> _ensureMonthlyWindow() async {
    final m = _monthAsiaTaipei();
    if (_monthlyMonth != m) {
      _monthlyMonth = m;
      _monthlyCounts.clear();
      await _persistMonthly();
    }
  }

  /// Explicitly refresh monthly window by reconciling with persisted values.
  /// Useful for tests or app lifecycle hooks when system month may jump.
  Future<void> refreshMonthlyWindow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final current = _monthAsiaTaipei();
      final stored = prefs.getString(_monthlyMonthKey) ?? _monthlyMonth;
      if (stored != current) {
        _monthlyMonth = current;
        _monthlyCounts.clear();
        await _persistMonthly();
      }
    } catch (_) {}
  }

  int getMonthlyCount(String itemKey) {
    // Check persisted month to allow tests to manipulate month and trigger reset.
    final m = _monthAsiaTaipei();
    final storedMonth = _prefs?.getString(_monthlyMonthKey) ?? _monthlyMonth;
    if (storedMonth != m) {
      _monthlyMonth = m;
      _monthlyCounts.clear();
      _persistMonthly();
      return 0;
    }
    return _monthlyCounts[itemKey] ?? 0;
  }

  bool canPurchaseMonthly(String itemKey, int maxCount) {
    final c = getMonthlyCount(itemKey);
    return c < maxCount; // allow up to max purchases per month
  }

  Future<void> purchaseMonthly(String itemKey) async {
    await _ensureMonthlyWindow();
    final next = (getMonthlyCount(itemKey) + 1);
    _monthlyCounts[itemKey] = next;
    await _persistMonthly();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Serialize as ["key=count", ...] to avoid JSON dependency.
      final list = _counts.entries.map((e) => '${e.key}=${e.value}').toList();
      await prefs.setStringList(_prefsKey, list);
    } catch (_) {
      // Ignore persistence failure silently in UI layer.
    }
  }

  Future<void> _persistDaily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list =
          _dailyCounts.entries.map((e) => '${e.key}=${e.value}').toList();
      await prefs.setString(_dailyDateKey, _dailyDate);
      await prefs.setStringList(_dailyCountsKey, list);
    } catch (_) {}
  }

  Future<void> _persistMonthly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list =
          _monthlyCounts.entries.map((e) => '${e.key}=${e.value}').toList();
      await prefs.setString(_monthlyMonthKey, _monthlyMonth);
      await prefs.setStringList(_monthlyCountsKey, list);
    } catch (_) {}
  }

  /// Clears all purchase records (used by Debug Panel reset all).
  Future<void> reset() async {
    _counts.clear();
    _dailyCounts.clear();
    _monthlyCounts.clear();
    await _persist();
    await _persistDaily();
    await _persistMonthly();
    notifyListeners();
  }

  // ---------- First N days window ----------
  int _diffDays(String startYmd, String endYmd) {
    try {
      final s = DateTime.parse('${startYmd}T00:00:00.000Z');
      final e = DateTime.parse('${endYmd}T00:00:00.000Z');
      // Dates we stored are in Asia/Taipei; comparing by yyyy-MM-dd is fine
      // if both are normalized strings. The Z suffix uses UTC midnight; since
      // both use same basis, the delta in days is consistent.
      return e.difference(s).inDays;
    } catch (_) {
      return 99999; // treat as very old
    }
  }

  bool _withinFirstDays(int n) {
    final today = _todayAsiaTaipei();
    if (_installDate.isEmpty) return false;
    final diff = _diffDays(_installDate, today);
    return diff < n; // day0..day(n-1) inclusive => n days
  }

  bool canPurchaseFirst7(String itemKey, int maxCount) {
    if (!_withinFirstDays(7)) return false;
    return getCount(itemKey) < maxCount;
  }

  bool canPurchaseFirst30(String itemKey, int maxCount) {
    if (!_withinFirstDays(30)) return false;
    return getCount(itemKey) < maxCount;
  }

  Future<void> purchaseFirstWindow(String itemKey) async {
    await purchase(itemKey);
  }
}
