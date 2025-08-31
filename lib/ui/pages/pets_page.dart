import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/pet_service.dart';
import 'package:idle_hippo/services/gacha_service.dart';
import 'package:idle_hippo/services/rewarded_ad_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/models/pet.dart';
import 'package:idle_hippo/ui/components/gacha_animation.dart';
import 'package:idle_hippo/ui/components/gacha_button.dart';
import 'package:idle_hippo/models/game_state.dart';

class PetsPage extends StatefulWidget {
  final GameState gameState;

  const PetsPage({super.key, required this.gameState});

  @override
  State<PetsPage> createState() => _PetsPageState();
}

class _PetsPageState extends State<PetsPage> with SingleTickerProviderStateMixin {
  final PetService _petService = PetService();
  final GachaService _gachaService = GachaService();
  final RewardedAdService _rewardedAdService = RewardedAdService();
  final LocalizationService _localization = LocalizationService();
  // 尚未揭示（尚未顯示名稱）的抽卡結果時間戳，暫時不顯示在歷史中
  final Set<int> _pendingRevealTimestamps = <int>{};
  // 抽卡系統是否完成初始化（避免首次點擊觸發初始化造成延遲）
  bool _gachaReady = false;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 初始化抽卡服務（完成後標記為就緒）
    _gachaService.initialize().then((_) {
      if (mounted) setState(() => _gachaReady = true);
    });
    // 廣告服務的初始化維持現狀（非阻塞 UI）
    _rewardedAdService.initialize(GameStateService());
  }

  // Hot reload 時呼叫，確保服務重新載入持久化資料
  @override
  void reassemble() {
    super.reassemble();
    _gachaService.ensureInitialized();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rewardedAdService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int currentStage = widget.gameState.mainQuest?.currentStage ?? 0;
    final bool isLocked = currentStage <= 3;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 主要內容（必要時灰階處理）
          ColorFiltered(
            colorFilter: isLocked
                ? const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
            child: Column(
              children: [
                // 標題區域
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _localization.getPageName('pets'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Tab 切換區域
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: const Color(0xFF00FFD1),
                    tabs: [
                      Tab(text: _localization.getPageName('pets')),
                      Tab(text: _localization.getString('pets.gacha.tab_title')),
                    ],
                  ),
                ),
              
              // Tab 內容區域
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPetsListTab(),
                    _buildGachaTab(),
                  ],
                ),
              ),
            ],
          ),
        ),

          // 鎖定覆蓋層（主線 < 3）
          isLocked
              ? Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _localization.getString(
                            'pets.locked.pet_system_unlock',
                            defaultValue: '寵物系統需要完成主線第三章解鎖',
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
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  /// 顯示 Loading 並在背景執行任務（完成後自動關閉 Loading）
  Future<T> _runWithLoading<T>(Future<T> Function() task) async {
    if (!mounted) return await task();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final result = await task();
      return result;
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// 建構寵物列表 Tab
  Widget _buildPetsListTab() {
    return StreamBuilder<PetState>(
      stream: _petService.petStateStream,
      initialData: _petService.currentState,
      builder: (context, snapshot) {
        final petState = snapshot.data ?? const PetState();
        final pets = _petService.getSortedPets();

        if (pets.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, color: Colors.white.withValues(alpha: 0.7), size: 72),
                const SizedBox(height: 16),
                Text(
                  _localization.getString('pets.no_pets_available'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.casino),
                  label: Text(_localization.getString('pets.gacha.tab_title')),
                )
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 當前裝備的寵物資訊
              if (petState.equippedPet != null) ...[
                const SizedBox(height: 8),
                _buildEquippedPetInfo(petState.equippedPet!),
                const SizedBox(height: 8),
              ],

              // 寵物列表（兩欄 Grid）
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return _buildPetCard(pet);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 建構抽卡 Tab
  Widget _buildGachaTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 抽獎券顯示
          StreamBuilder<int>(
            stream: _gachaService.petTicketsStream,
            initialData: _gachaService.getPetTickets(),
            builder: (context, snapshot) {
              final tickets = snapshot.data ?? 0;
              return TicketDisplay(
                ticketCount: tickets,
                backgroundColor: Colors.amber,
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // 抽卡按鈕（左右兩欄）
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: _gachaService.petTicketsStream,
                  initialData: _gachaService.getPetTickets(),
                  builder: (context, snapshot) {
                    final tickets = snapshot.data ?? 0;
                    return GachaButton(
                      text: _localization.getString('pets.gacha.single_draw'),
                      costText: _localization.getString('pets.gacha.single_draw_cost'),
                      onPressed: _performSingleDraw,
                      isEnabled: tickets >= 1 && _gachaReady,
                      primaryColor: Colors.blue,
                      icon: Icons.casino,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<int>(
                  stream: _gachaService.petTicketsStream,
                  initialData: _gachaService.getPetTickets(),
                  builder: (context, snapshot) {
                    final tickets = snapshot.data ?? 0;
                    return GachaButton(
                      text: _localization.getString('pets.gacha.ten_plus_one_draw'),
                      costText: _localization.getString('pets.gacha.ten_plus_one_cost'),
                      onPressed: _performTenPlusOneDraw,
                      isEnabled: tickets >= 10 && _gachaReady,
                      primaryColor: Colors.purple,
                      icon: Icons.auto_awesome,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          
          // 抽卡歷史
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localization.getString('pets.gacha.history_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // const SizedBox(height: 8),
                  Expanded(
                    child: _buildGachaHistory(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建構抽卡歷史列表
  Widget _buildGachaHistory() {
    return StreamBuilder<List<GachaHistoryRecord>>(
      stream: _gachaService.gachaHistoryStream,
      initialData: _gachaService.getGachaHistory(),
      builder: (context, snapshot) {
        final history = snapshot.data ?? const <GachaHistoryRecord>[];
        // 過濾尚未揭示的紀錄（等動畫顯示名稱後再插入）
        final visible = history
            .where((r) => !_pendingRevealTimestamps.contains(r.timestamp))
            .toList();

        if (visible.isEmpty) {
          return Center(
            child: Text(
              _localization.getString('pets.gacha.no_history'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final record = visible[index];
            final rarityColor = _getRarityColorFromString(record.rarity);

            final petKey = (record.petKey ?? '').trim();
            final localizedName = petKey.isNotEmpty
                ? _localization.getString('pets.names.$petKey', defaultValue: record.name)
                : _localization.getString(record.name, defaultValue: record.name);
            return GachaHistoryCard(
              rarity: record.rarity,
              name: localizedName,
              timestamp: record.timestamp,
              rarityColor: rarityColor,
            );
          },
        );
      },
    );
  }

  /// 取得稀有度顏色 (從 PetRarity 枚舉)
  Color _getRarityColor(PetRarity rarity) {
    switch (rarity) {
      case PetRarity.ssr:
        return Colors.amber;
      case PetRarity.sr:
        return Colors.purple;
      case PetRarity.s:
        return Colors.blue;
      case PetRarity.r:
        return Colors.green;
      case PetRarity.rr:
        return Colors.grey;
    }
  }

  /// 取得稀有度顏色 (從字串)
  Color _getRarityColorFromString(String rarity) {
    switch (rarity) {
      case 'SSR':
        return Colors.amber;
      case 'SR':
        return Colors.purple;
      case 'S':
        return Colors.blue;
      case 'R':
        return Colors.green;
      case 'RR':
      default:
        return Colors.grey;
    }
  }

  /// 執行單抽
  Future<void> _performSingleDraw() async {
    try {
      final result = await _runWithLoading(() async {
        return await _gachaService.performSingleDraw();
      });
      // 預先快取圖片，避免動畫開啟瞬間卡頓
      if (mounted) {
        try { await precacheImage(AssetImage(result.imagePath), context); } catch (_) {}
        _showGachaAnimation([result]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.getString('pets.gacha.draw_failed')}: $e')),
        );
      }
    }
  }

  /// 執行廣告十一連抽
  Future<void> _performTenPlusOneDrawWithAd() async {
    try {
      final results = await _gachaService.drawTenPlusOneWithAd();
      if (mounted) {
        _showGachaAnimation(results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_localization.getString('pets.gacha.draw_failed')}: $e')),
        );
      }
    }
  }

  /// 執行十一連抽
  Future<void> _performTenPlusOneDraw() async {
    try {
      final results = await _runWithLoading(() async {
        return await _gachaService.performTenPlusOneDraw();
      });
      // 立即顯示動畫；圖片改為在 onReveal 時非阻塞微前載
      if (mounted) {
        _showGachaAnimation(results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('抽卡失敗: $e')),
        );
      }
    }
  }

  /// 顯示抽卡動畫
  void _showGachaAnimation(List<GachaResult> results) {
    // 在動畫開始前，先將這批結果標記為「待揭示」，暫不顯示在歷史清單
    setState(() {
      _pendingRevealTimestamps.addAll(results.map((e) => e.timestamp));
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GachaAnimationDialog(
        results: results,
        onReveal: (res) {
          // 非阻塞微前載：當前與下一張圖片
          if (mounted) {
            try { precacheImage(AssetImage(res.imagePath), context); } catch (_) {}
            final idx = results.indexWhere((e) => e.timestamp == res.timestamp);
            if (idx != -1 && idx + 1 < results.length) {
              try { precacheImage(AssetImage(results[idx + 1].imagePath), context); } catch (_) {}
            }
          }
          // 單抽：名稱揭示時釋放
          if (results.length == 1 && mounted) {
            setState(() {
              _pendingRevealTimestamps.remove(res.timestamp);
            });
          }
        },
        onAdvance: (res) {
          // 多抽：使用者按「下一個/確定」時釋放
          if (results.length > 1 && mounted) {
            setState(() {
              _pendingRevealTimestamps.remove(res.timestamp);
            });
          }
        },
        onComplete: () {
          // 動畫結束後，若尚有殘留（例如跳過）則一次性釋放
          if (mounted) {
            setState(() {
              _pendingRevealTimestamps.clear();
            });
          }
          // 兩階段提交：動畫完成後提交 pending 批次（冪等、非阻塞）
          try { _gachaService.commitPendingBatchIfAny(); } catch (_) {}
        },
      ),
    );
  }


  /// 建構當前裝備寵物資訊
  Widget _buildEquippedPetInfo(Pet pet) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getRarityColor(pet.rarity), width: 2),
      ),
      child: Row(
        children: [
          // 寵物圖片
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage(pet.imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 寵物資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_localization.getString('pets.names.${pet.petKey}', defaultValue: pet.name)} ${pet.rarity.value}',
                  style: TextStyle(
                    color: _getRarityColor(pet.rarity),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_localization.getString('ui.level')}: ${pet.level}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  '${_localization.getString('pets.idle_income')}: ${pet.baseIdlePerSec}${_localization.getString('common.perSecond', defaultValue: '/s')}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 建構寵物卡片
  Widget _buildPetCard(Pet pet) {
    final currentIdlePerSec = _petService.getPetIdlePerSec(pet);
    final isEquipped = pet.isEquipped;

    return Container(
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pet.rarity.getColor(),
          width: isEquipped ? 2 : 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxHeight * 0.38; // 依卡片高度自適應
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 圖片（置中、等比縮放）
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: imageHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Image.asset(
                        pet.imagePath,
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stack) => Container(
                          alignment: Alignment.topCenter,
                          color: Colors.white10,
                          child: const Icon(Icons.pets, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 名稱與稀有度標籤
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _localization.getString('pets.names.${pet.petKey}', defaultValue: pet.name),
                      maxLines: 2,
                      softWrap: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: pet.rarity.getColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pet.rarity.value,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側資訊欄
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_localization.getUI('level')}: ${pet.level}',
                          maxLines: 2,
                          softWrap: true,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_localization.getString('pets.idle_income', defaultValue: '放置收益')}: ${currentIdlePerSec.toStringAsFixed(2)}${_localization.getString('common.perSecond', defaultValue: '/s')}',
                          maxLines: 2,
                          softWrap: true,
                          style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_localization.getString('pets.upgrade_points', defaultValue: '升級點數')}: ${pet.upgradePoints}/${pet.nextLevelRequirement}',
                          maxLines: 2,
                          softWrap: true,
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右側按鈕（裝備/卸下 + 升級）
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 40,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _onPetTap(pet),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: isEquipped ? Colors.green : const Color(0xFF00FFD1),
                              foregroundColor: isEquipped ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isEquipped ? _localization.getUI('unequip') : _localization.getUI('equip'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: pet.canUpgrade ? () => _upgradePet(pet) : null,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: pet.canUpgrade ? Colors.blue : Colors.grey,
                              disabledBackgroundColor: Colors.grey,
                              disabledForegroundColor: Colors.white70,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _localization.getUI('upgrade'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
            ],
          );
        },
      ),
    );
  }

  void _onPetTap(Pet pet) {
    if (pet.isEquipped) {
      // 如果已裝備，則取消裝備
      _petService.unequipAll();
    } else {
      // 否則裝備此寵物
      _petService.equipPet(pet);
    }
  }

  void _upgradePet(Pet pet) async {
    final success = await _petService.upgradePet(pet);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_localization.getString('pets.names.${pet.petKey}', defaultValue: pet.name)} ${_localization.getString('pets.upgrade_success', defaultValue: '升級成功！')}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

}
