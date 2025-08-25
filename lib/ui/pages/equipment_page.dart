import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/equipment_service.dart';

class EquipmentPage extends StatefulWidget {
  final double memePoints;
  final Map<String, int> equipments;
  final void Function(String id) onUpgrade;
  final void Function(String id) onUpgradeIdle;
  final List<String> unlockedRewards;
  final int initialTabIndex;

  const EquipmentPage({
    super.key,
    required this.memePoints,
    required this.equipments,
    required this.onUpgrade,
    required this.onUpgradeIdle,
    required this.unlockedRewards,
    this.initialTabIndex = 0,
  });

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 1));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localization.getPageName('equipment'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: localization.getString('tab.equip.tap')),
                Tab(text: localization.getString('tab.equip.idle')),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFF00FFD1),
              labelStyle: const TextStyle(
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTapEquipmentGrid(),
                _buildIdleEquipmentGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapEquipmentGrid() {
    final localization = LocalizationService();
    final equipmentService = EquipmentService();
    final items = equipmentService.listTapEquipments();
    
    return GridView.builder(
      padding: const EdgeInsets.only(top: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final e = items[index];
        final id = (e["id"] ?? '') as String;
        final icon = (e['icon'] ?? '') as String;
        final nameKey = (e['name_key'] ?? '') as String;
        final currentLevel = widget.equipments[id] ?? 0;
        final nextCost = equipmentService.getNextCost(id, currentLevel);
        final unlocked = equipmentService.isUnlockedBy(widget.equipments, id);
        final canUpgrade = nextCost != null && unlocked && widget.memePoints >= nextCost;
        final isMax = nextCost == null;

        final currentBonus = equipmentService.cumulativeBonusFor(id, currentLevel);
        final nextBonus = equipmentService.cumulativeBonusFor(id, currentLevel + 1);

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon（縮小 50%，置中）
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Image.asset(
                          icon,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          errorBuilder: (c, e, s) => Container(
                            alignment: Alignment.topCenter,
                            color: Colors.white10,
                            child: const Icon(Icons.videogame_asset, color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    localization.getString(nameKey),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left info column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${localization.getUI('level')}: $currentLevel',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 1),
                            Builder(
                              builder: (_) {
                                final double delta = !isMax ? (nextBonus - currentBonus) : 0.0;
                                final bonusText = !isMax
                                    ? '+${_fmt(currentBonus)}(+${_fmt(delta)})'
                                    : '+${_fmt(currentBonus)}';
                                return Text(
                                  '${localization.getUI('bonus')}: $bonusText',
                                  style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12),
                                );
                              },
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${localization.getUI('cost')}: ${nextCost ?? '-'}',
                              style: TextStyle(
                                color: (!isMax && canUpgrade) ? Colors.yellow : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right square button
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (!isMax && canUpgrade) ? () => widget.onUpgrade(id) : null,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: (!isMax && canUpgrade) ? const Color(0xFF00FFD1) : Colors.grey,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              !isMax ? localization.getUI('upgrade') : localization.getUI('maxLevel'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!unlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        () {
                          final req = e['requires'] as Map<String, dynamic>?;
                          if (req == null) return localization.getUI('locked');
                          final rid = req['id'] as String? ?? '';
                          final lv = (req['level'] as num?)?.toInt() ?? 0;
                          final ridName = localization.getString('equip.$rid.name', defaultValue: rid);
                          final requires = localization.getUI('requires');
                          final toLevel = localization.getUI('toLevel');
                          // e.g. Requires <name> to Lv<lv>
                          return '$requires $ridName $toLevel$lv';
                        }(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIdleEquipmentGrid() {
    final localization = LocalizationService();
    final equipmentService = EquipmentService();
    final items = equipmentService.listIdleEquipments();
    
    return GridView.builder(
      padding: const EdgeInsets.only(top: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final e = items[index];
        final id = (e["id"] ?? '') as String;
        final icon = (e['icon'] ?? '') as String;
        final nameKey = (e['name_key'] ?? '') as String;
        final currentLevel = widget.equipments[id] ?? 0;
        final nextCost = equipmentService.getIdleNextCost(id, currentLevel);
        final unlocked = equipmentService.isIdleEquipmentUnlocked(widget.equipments, id);
        // 需同時滿足主線解鎖（僅針對 youtube）
        final questUnlocked = widget.unlockedRewards.contains('equipment.$id');
        final uiUnlocked = unlocked && (id != 'youtube' || questUnlocked);
        final canUpgrade = nextCost != null && uiUnlocked && widget.memePoints >= nextCost;
        final isMax = nextCost == null;

        final currentBonus = equipmentService.cumulativeIdleBonusFor(id, currentLevel);
        final nextBonus = equipmentService.cumulativeIdleBonusFor(id, currentLevel + 1);

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon（縮小 50%，置中）
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: () {
                          final img = Image.asset(
                            icon,
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            errorBuilder: (c, e, s) => Container(
                              alignment: Alignment.topCenter,
                              color: Colors.white10,
                              child: const Icon(Icons.auto_awesome, color: Colors.white54),
                            ),
                          );
                          if (!uiUnlocked) {
                            // 鎖定時套用灰階
                            return ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: img,
                            );
                          }
                          return img;
                        }(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    localization.getString(nameKey),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left info column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${localization.getUI('level')}: $currentLevel',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 1),
                            Builder(
                              builder: (_) {
                                final double delta = !isMax ? (nextBonus - currentBonus) : 0.0;
                                final bonusText = !isMax
                                    ? '+${_fmt(currentBonus)}/s(+${_fmt(delta)})'
                                    : '+${_fmt(currentBonus)}/s';
                                return Text(
                                  bonusText,
                                  style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12),
                                );
                              },
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${localization.getUI('cost')}: ${nextCost ?? '-'}',
                              style: TextStyle(
                                color: (!isMax && canUpgrade) ? Colors.yellow : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right square button
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (!isMax && canUpgrade) ? () => widget.onUpgradeIdle(id) : null,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: (!isMax && canUpgrade) ? const Color(0xFF00FFD1) : Colors.grey,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              !isMax ? localization.getUI('upgrade') : localization.getUI('maxLevel'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!uiUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        () {
                          // 若為 youtube 且尚未完成主線第一章解鎖，顯示專屬提示
                          if (id == 'youtube' && !questUnlocked) {
                            return localization.getString(
                              'equip.lock.need_main_quest_stage1',
                              defaultValue: '需要完成主線第一章解鎖',
                            );
                          }
                          final unlock = e['unlock'] as Map<String, dynamic>?;
                          if (unlock == null) return localization.getUI('locked');
                          final reqId = unlock['id'] as String? ?? '';
                          final reqLevel = (unlock['level'] as num?)?.toInt() ?? 0;
                          final reqName = localization.getString('equip.$reqId.name', defaultValue: reqId);
                          return localization.getString('equip.lock.need_level')
                              .replaceAll('{name}', reqName)
                              .replaceAll('{level}', reqLevel.toString());
                        }(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
