import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/models/game_state.dart';

class TitlesPage extends StatefulWidget {
  const TitlesPage({super.key});

  @override
  State<TitlesPage> createState() => _TitlesPageState();
}

class _TitlesPageState extends State<TitlesPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _badgePulseController;
  late Animation<double> _badgePulseAnimation;
  late final ValueNotifier<GameState> _gsNotifier;

  // 簡單資料模型（MVP 本地狀態）
  late List<_TitleItem> _claimed; // 已取得
  late List<_TitleItem> _unclaimed; // 未取得（含 locked/claimable）

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _badgePulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _badgePulseAnimation = Tween<double>(begin: 0.9, end: 1.2).animate(
      CurvedAnimation(parent: _badgePulseController, curve: Curves.easeInOut),
    );
    // 監聽 GameState 變化，當稱號/裝備等條件變更時自動重載，避免需要切換頁面
    _gsNotifier = GameStateService().gameState;
    _gsNotifier.addListener(_onGameStateChanged);
    _loadTitles();
  }

  // 正規化 titles.json 的 equip_id → 專案內部裝備 id（去除前綴）
  // 注意：不強制轉小寫，避免打破 tap 類裝備如 faceMask 的 camelCase 鍵
  String _normalizeEquipId(String raw) {
    var id = raw.trim();
    if (id.startsWith('equip.')) {
      id = id.substring('equip.'.length);
    }
    // 別名映射（titles.json → equipments.json 實際 ID）
    switch (id) {
      case '114514':
        return 'title_114514';
      case 'Mask':
      case 'mask':
        return 'faceMask';
      default:
        return id;
    }
  }

  // 檢查裝備等級是否達到要求
  bool _isEquipmentLevelReached(String equipId, int requiredLevel) {
    try {
      final normalized = _normalizeEquipId(equipId);
      final altLower = normalized.toLowerCase();
      final gameState = GameStateService().gameState.value;
      // 嘗試多種鍵名（避免大小寫不一致）：
      final currentLevel =
          gameState.equipments[normalized] ??
          gameState.equipments[altLower] ??
          gameState.equipments[equipId] ??
          0;
      return currentLevel >= requiredLevel;
    } catch (_) {
      return false;
    }
  }

  void _loadTitles() {
    final list =
        (ConfigService().getValue('titles.titles', defaultValue: []) as List)
            .cast<Map<String, dynamic>?>()
            .whereType<Map<String, dynamic>>()
            .toList();
    final loc = LocalizationService();

    // 獲取當前遊戲狀態
    int currentMainStage = 0;
    try {
      currentMainStage =
          GameStateService().gameState.value.mainQuest?.currentStage ?? 0;
    } catch (_) {
      currentMainStage = 0;
    }

    // 以新的 schema 欄位：id / name_key / desc_key / hidden_desc_key / type / condition
    final items = list.map((e) {
      final id = e['id']?.toString() ?? '';
      final nameKey = e['name_key']?.toString();
      final descKey = e['desc_key']?.toString();
      final hiddenDescKey = e['hidden_desc_key']?.toString();
      final type = e['type']?.toString();
      final condition = e['condition'] as Map<String, dynamic>?;

      // 檢查稱號解鎖條件
      bool isConditionMet = false;
      if (condition != null) {
        final kind = condition['kind']?.toString();

        if (kind == 'main_stage_done') {
          final stage = (condition['stage'] as num?)?.toInt() ?? 0;
          isConditionMet = currentMainStage >= stage;
        }
        // 單一裝備等級達標
        else if (kind == 'equip_level_reach') {
          final equipId = condition['equip_id'] as String?;
          final level = (condition['level'] as num?)?.toInt() ?? 0;
          isConditionMet =
              equipId != null && _isEquipmentLevelReached(equipId, level);
        }
        // 裝備配對等級條件（所有 pair 皆需達成）
        else if (kind == 'equip_pair_levels') {
          final pairs = condition['pairs'] as List?;
          if (pairs != null) {
            isConditionMet = pairs.every((pair) {
              final equipId = pair is Map ? pair['equip_id'] as String? : null;
              final level = pair is Map
                  ? (pair['level'] as num?)?.toInt() ?? 0
                  : 0;
              return equipId != null &&
                  _isEquipmentLevelReached(equipId, level);
            });
          }
        }
        // 抽卡稀有度達成次數
        else if (kind == 'gacha_obtained_rarity') {
          final rarity = (condition['rarity'] as String?)?.toUpperCase() ?? '';
          final count = (condition['count'] as num?)?.toInt() ?? 1;
          try {
            final records = GameStateService().gameState.value.gachaHistory;
            final got = records
                .where((r) => r.rarity.toUpperCase() == rarity)
                .length;
            isConditionMet = got >= count;
          } catch (_) {
            isConditionMet = false;
          }
        }
        // 可以添加其他類型的條件檢查
      }

      final name = nameKey != null
          ? loc.getString(nameKey, defaultValue: id)
          : id;
      final desc = descKey != null
          ? loc.getString(descKey, defaultValue: '')
          : '';
      final hiddenDesc = hiddenDescKey != null
          ? loc.getString(
              hiddenDescKey,
              defaultValue: loc.getString('title.hidden', defaultValue: '????'),
            )
          : loc.getString('title.hidden', defaultValue: '????');

      return _TitleItem(
        id: id,
        name: name,
        desc: desc,
        hiddenDesc: hiddenDesc,
        isHiddenType: type == 'hidden',
        status: _TitleStatus.locked,
        conditionMet: isConditionMet,
      );
    }).toList();

    // 從持久化狀態覆蓋 status
    TitlesState? titlesState;
    try {
      titlesState = GameStateService().gameState.value.titles;
    } catch (_) {
      titlesState = null;
    }

    final List<_TitleItem> claimed = [];
    final List<_TitleItem> unclaimed = [];
    final Map<String, String> newStates = {};
    bool hasNewClaimable = false;

    for (final it in items) {
      final persisted = titlesState?.states[it.id];
      _TitleStatus status;

      if (persisted == 'claimed') {
        status = _TitleStatus.claimed;
      } else if (it.conditionMet) {
        // 如果條件已滿足且尚未領取，則設置為可領取
        status = _TitleStatus.claimable;
        newStates[it.id] = 'claimable';
        hasNewClaimable = true;
      } else {
        status = _TitleStatus.locked;
      }

      final withStatus = it.copyWith(status: status);
      if (status == _TitleStatus.claimed) {
        claimed.add(withStatus);
      } else {
        unclaimed.add(withStatus);
      }
    }

    // 二次通過：支援 collect_all_titles_except
    // 條件：除 exclude 清單與自身之外，其餘稱號皆已「已領取」
    if (titlesState != null) {
      final claimedIds = <String>{...claimed.map((e) => e.id)};
      final allIds = <String>{...items.map((e) => e.id)};
      final collectItems = items.where(
        (e) =>
            ((list.firstWhere(
                      (m) => m['id']?.toString() == e.id,
                      orElse: () => const {},
                    )
                    as Map)['condition']
                as Map<String, dynamic>?)?['kind'] ==
            'collect_all_titles_except',
      );

      for (final it in collectItems) {
        final cond =
            (list.firstWhere((m) => m['id']?.toString() == it.id)
                    as Map)['condition']
                as Map<String, dynamic>;
        final exclude = (cond['exclude'] as List?)?.cast<String>() ?? const [];
        final targetSet = allIds.difference({it.id, ...exclude});
        final allClaimed = targetSet.every((id) => claimedIds.contains(id));
        if (allClaimed) {
          // 更新在 unclaimed（本地工作清單）中的狀態
          final idx = unclaimed.indexWhere((x) => x.id == it.id);
          if (idx >= 0) {
            final updated = unclaimed[idx].copyWith(
              status: _TitleStatus.claimable,
            );
            unclaimed[idx] = updated;
            newStates[it.id] = 'claimable';
            hasNewClaimable = true;
          }
        }
      }
    }

    // 如果有新的可領取稱號，更新遊戲狀態（延後到 frame 結束後再寫入，避免 build 中觸發）
    if (hasNewClaimable && titlesState != null) {
      final baseTitles = titlesState;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final gs = GameStateService().gameState.value;
          final updatedStates = Map<String, String>.from(baseTitles.states)
            ..addAll(newStates);
          final newTitles = baseTitles.copyWith(
            states: updatedStates,
            hasClaimable: true,
          );
          await GameStateService().updateGameState(
            gs.copyWith(titles: newTitles),
          );
        } catch (_) {
          // 忽略錯誤
        }
      });
    }

    _claimed = claimed;
    _unclaimed = unclaimed;

    // 初始時計算紅點狀態，若不同步則更新 GameState（延後到 frame 結束後再寫入）
    final hasClaimable = _hasClaimable;
    if (titlesState != null && titlesState.hasClaimable != hasClaimable) {
      final baseTitles = titlesState;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final gs = GameStateService().gameState.value;
          final newTitles = baseTitles.copyWith(hasClaimable: hasClaimable);
          await GameStateService().updateGameState(
            gs.copyWith(titles: newTitles),
          );
        } catch (_) {
          // 忽略錯誤
        }
      });
    }
  }

  bool get _hasClaimable =>
      _unclaimed.any((e) => e.status == _TitleStatus.claimable);

  void _claim(_TitleItem item) {
    setState(() {
      // 標記為已取得並移動到已取得清單
      final idx = _unclaimed.indexWhere((t) => t.id == item.id);
      if (idx >= 0) {
        final claimedItem = _unclaimed[idx].copyWith(
          status: _TitleStatus.claimed,
        );
        _unclaimed.removeAt(idx);
        _claimed.insert(0, claimedItem); // 置頂（新到舊）
      }
    });

    // 寫回持久化（狀態、claimedAt、紅點）
    try {
      final svc = GameStateService();
      final current = svc.gameState.value;
      final titles = current.titles ?? const TitlesState();
      final newStates = Map<String, String>.from(titles.states);
      newStates[item.id] = 'claimed';
      final newClaimedAt = Map<String, int>.from(titles.claimedAt);
      newClaimedAt[item.id] = DateTime.now().toUtc().millisecondsSinceEpoch;
      final hasClaimable = _unclaimed.any(
        (e) => e.status == _TitleStatus.claimable,
      );
      final newTitles = titles.copyWith(
        states: newStates,
        claimedAt: newClaimedAt,
        hasClaimable: hasClaimable,
      );
      svc.updateGameState(current.copyWith(titles: newTitles));
      // 立即重檢 collect_all_titles_except，若條件已滿足，直接把目標標為可領取
      _recheckCollectAllTitlesExcept();
    } catch (_) {
      // 服務未初始化時忽略持久化，避免閃退（MVP）
    }
  }

  void _recheckCollectAllTitlesExcept() {
    try {
      final list =
          (ConfigService().getValue('titles.titles', defaultValue: []) as List)
              .cast<Map<String, dynamic>?>()
              .whereType<Map<String, dynamic>>()
              .toList();

      final claimedIds = <String>{..._claimed.map((e) => e.id)};
      final allIds = <String>{
        ...list
            .map((e) => e['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      };

      bool updated = false;
      for (final m in list) {
        final id = m['id']?.toString() ?? '';
        final cond = m['condition'] as Map<String, dynamic>?;
        if (id.isEmpty ||
            (cond?['kind']?.toString() != 'collect_all_titles_except')) {
          continue;
        }

        final exclude = (cond?['exclude'] as List?)?.cast<String>() ?? const [];
        final targetSet = allIds.difference({id, ...exclude});
        final allClaimed = targetSet.every((tid) => claimedIds.contains(tid));
        if (allClaimed) {
          final idx = _unclaimed.indexWhere((x) => x.id == id);
          if (idx >= 0 && _unclaimed[idx].status != _TitleStatus.claimable) {
            _unclaimed[idx] = _unclaimed[idx].copyWith(
              status: _TitleStatus.claimable,
            );
            updated = true;
          }
        }
      }

      if (updated) {
        // 同步紅點持久化
        final svc = GameStateService();
        final current = svc.gameState.value;
        final titles = current.titles ?? const TitlesState();
        final newStates = Map<String, String>.from(titles.states);
        for (final it in _unclaimed.where(
          (e) => e.status == _TitleStatus.claimable,
        )) {
          if (newStates[it.id] != 'claimed') {
            newStates[it.id] = 'claimable';
          }
        }
        final hasClaimable = _unclaimed.any(
          (e) => e.status == _TitleStatus.claimable,
        );
        final newTitles = titles.copyWith(
          states: newStates,
          hasClaimable: hasClaimable,
        );
        svc.updateGameState(current.copyWith(titles: newTitles));
        setState(() {});
      }
    } catch (_) {
      // 忽略非關鍵錯誤
    }
  }

  @override
  void dispose() {
    _badgePulseController.dispose();
    _gsNotifier.removeListener(_onGameStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    // 輕量重算（含 hidden 與 collect_all_titles_except），讓按鈕無需換頁也會更新
    setState(() {
      _loadTitles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();

    // 讀取主線任務階段（服務若未初始化則預設鎖定）
    int currentStage = 0;
    bool isLocked = true;
    try {
      currentStage =
          GameStateService().gameState.value.mainQuest?.currentStage ?? 0;
      // 解鎖條件：完成第二章後可使用（<= 2 鎖定）
      isLocked = currentStage <= 2;
    } catch (_) {
      // 若服務尚未初始化，維持鎖定，避免閃退
      isLocked = true;
    }

    return Stack(
      children: [
        // 主要內容（必要時灰階處理）
        ColorFiltered(
          colorFilter: isLocked
              ? const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.getPageName('titles'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Tabs: 未取得 / 已取得（未取得在前，支援紅點）
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      // 未取得 Tab（右上角顯示紅點：當存在可領取稱號時）
                      Tab(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                localization.getString(
                                  'title.tab.locked',
                                  defaultValue: '未取得',
                                ),
                              ),
                            ),
                            if (_hasClaimable)
                              Positioned(
                                right: -6,
                                top: -2,
                                child: ScaleTransition(
                                  scale: _badgePulseAnimation,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Tab(
                        text: localization.getString(
                          'title.tab.unlocked',
                          defaultValue: '已取得',
                        ),
                      ),
                    ],
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: const Color(0xFF00FFD1),
                    labelStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLockedTab(localization),
                      _buildUnlockedTab(localization),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 鎖定覆蓋層（主線未達第二章完成）
        if (isLocked)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    localization.getString(
                      'title.lock.title_system_unlock',
                      defaultValue: '稱號系統需要完成主線第二章解鎖',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLockedTab(LocalizationService localization) {
    // 排序：claimable 先，其後 locked（維持原順序）
    final claimables = _unclaimed
        .where((e) => e.status == _TitleStatus.claimable)
        .toList();
    final lockeds = _unclaimed
        .where((e) => e.status == _TitleStatus.locked)
        .toList();
    final list = [...claimables, ...lockeds];

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Center(
          child: Text(
            localization.getString(
              'title.all_obtained',
              defaultValue: '全部稱號已取得！',
            ),
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width / 10 - 10,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _TitleCard(
          item: item,
          onClaim: item.status == _TitleStatus.claimable
              ? () => _claim(item)
              : null,
          localization: localization,
        );
      },
    );
  }

  Widget _buildUnlockedTab(LocalizationService localization) {
    if (_claimed.isEmpty) {
      return const Center(
        child: Text('—', style: TextStyle(color: Colors.white38)),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _claimed.length,
      itemBuilder: (context, index) {
        final item = _claimed[index];
        return _TitleCard(item: item, localization: localization);
      },
    );
  }
}

class _TitleCard extends StatelessWidget {
  final _TitleItem item;
  final VoidCallback? onClaim;
  final LocalizationService localization;

  const _TitleCard({
    required this.item,
    this.onClaim,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    final locked = item.status == _TitleStatus.locked;
    final claimable = item.status == _TitleStatus.claimable;
    final claimed = item.status == _TitleStatus.claimed;

    final displayName = item.name;

    final displayDesc = locked
        ? (item.isHiddenType ? item.hiddenDesc : item.desc)
        : item.desc;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double iconSide = (constraints.maxHeight * 0.12).clamp(36.0, 48.0);
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: claimed
                  ? const Color(0xFFE89A00)
                  : (claimable ? const Color(0xFFE89A00) : Colors.white24),
              width: 5,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 佔位圖示（隨卡片高度縮放）
                  Container(
                    height: iconSide,
                    width: iconSide,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.emoji_events, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (!claimed) const Spacer(),
                  if (!claimed)
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: claimable ? onClaim : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: claimable
                              ? const Color(0xFFE89A00)
                              : Colors.grey.shade900,
                          foregroundColor:
                              claimable ? Colors.black : Colors.white,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            localization.getString(
                              'title.btn.claim',
                              defaultValue: '領取',
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
              if (locked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _TitleStatus { locked, claimable, claimed }

class _TitleItem {
  final String id;
  final String name;
  final String desc;
  final String hiddenDesc;
  final bool isHiddenType;
  final _TitleStatus status;
  final bool conditionMet;

  const _TitleItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.hiddenDesc,
    required this.isHiddenType,
    required this.status,
    this.conditionMet = false,
  });

  _TitleItem copyWith({
    String? id,
    String? name,
    String? desc,
    String? hiddenDesc,
    bool? isHiddenType,
    _TitleStatus? status,
    bool? conditionMet,
  }) {
    return _TitleItem(
      id: id ?? this.id,
      name: name ?? this.name,
      desc: desc ?? this.desc,
      hiddenDesc: hiddenDesc ?? this.hiddenDesc,
      isHiddenType: isHiddenType ?? this.isHiddenType,
      status: status ?? this.status,
      conditionMet: conditionMet ?? this.conditionMet,
    );
  }
}
