import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/pet_service.dart';
import 'package:idle_hippo/models/pet.dart';

class PetsPage extends StatefulWidget {
  const PetsPage({super.key});

  @override
  State<PetsPage> createState() => _PetsPageState();
}

class _PetsPageState extends State<PetsPage> {
  final PetService _petService = PetService();
  final LocalizationService _localization = LocalizationService();

  @override
  void initState() {
    super.initState();
    // 若尚未初始化（無任何寵物），從設定檔建立初始寵物
    if (_petService.currentState.pets.isEmpty) {
      // 非同步初始化，狀態會透過 stream 送出
      _petService.initialize(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<PetState>(
        stream: _petService.petStateStream,
        initialData: _petService.currentState,
        builder: (context, snapshot) {
          final petState = snapshot.data ?? const PetState();
          final pets = _petService.getSortedPets();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            child: Column(
              children: [
                // 標題
                Align(
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
                
                // 當前裝備的寵物資訊
                if (petState.equippedPet != null)
                  _buildEquippedPetInfo(petState.equippedPet!),
                
                // 寵物列表（兩欄 Grid）
                Expanded(
                  child: pets.isEmpty
                      ? _buildEmptyState()
                      : _buildPetGrid(pets),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEquippedPetInfo(Pet equippedPet) {
    final currentIdlePerSec = _petService.getPetIdlePerSec(equippedPet);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: equippedPet.rarity.getColor(), width: 2),
      ),
      child: Column(
        children: [
          Text(
            _localization.getString('pets.equipped_title', defaultValue: '已裝備寵物'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 寵物圖片
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: equippedPet.rarity.getColor(), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    equippedPet.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.pets, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 寵物資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_localization.getString(equippedPet.name, defaultValue: equippedPet.name)} (${equippedPet.rarity.value})',
                      style: TextStyle(
                        color: equippedPet.rarity.getColor(),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_localization.getUI('level')}: ${equippedPet.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${_localization.getString('pets.idle_income', defaultValue: '放置收益')}: ${currentIdlePerSec.toStringAsFixed(2)}/s',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(color: Colors.green, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPetGrid(List<Pet> pets) {
    final aspect = _computeCardAspect(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // 依語系與字級自適應卡片比例
        childAspectRatio: aspect,
      ),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        final pet = pets[index];
        return _buildPetCard(pet);
      },
    );
  }

  // 根據語系與文字縮放比，自適應卡片比例，避免保留過多空間或溢位
  double _computeCardAspect(BuildContext context) {
    final lang = _localization.currentLanguage;
    // 使用新的 textScaler 取代已棄用的 textScaleFactor
    final scaler = MediaQuery.of(context).textScaler;
    final ts = scaler.scale(1.0); // 以字級 1.0 的縮放結果近似視為縮放係數
    // 基準：中文較短，卡片可矮一些；其他語系字較長，卡片略高。
    double base = (lang == 'zh') ? 0.8 : 0.66;
    // 若使用者系統字級偏大，適度增高卡片（降低 aspect）
    if (ts > 1.0) {
      final delta = (ts - 1.0).clamp(0.0, 0.5); // 最多調 0.5
      base -= 0.06 * delta / 0.5; // 最多降到 ~0.64
    }
    return base;
  }

  Widget _buildPetCard(Pet pet) {
    final currentIdlePerSec = _petService.getPetIdlePerSec(pet);
    final isEquipped = pet.isEquipped;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
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
              final imageHeight = constraints.maxHeight * 0.3; // 依卡片高度自適應
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
                      _localization.getString(pet.name, defaultValue: pet.name),
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
                          '${_localization.getString('pets.idle_income', defaultValue: '放置收益')}: ${currentIdlePerSec.toStringAsFixed(2)}/s',
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
                        Text(
                          '${_localization.getString('pets.next_level', defaultValue: '下一級需要')}: ${pet.nextLevelRequirement}',
                          maxLines: 2,
                          softWrap: true,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                          height: 44,
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
                          height: 44,
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
        ),
        // 覆蓋在卡片黑色區域底部的測試加點按鈕（僅在未達升級門檻時顯示）
        // if (!pet.canUpgrade)
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: () => _addTestPoints(pet),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _localization.getString('pets.test_add_points', defaultValue: '加點(測試)'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            _localization.getString('pets.no_pets_available', defaultValue: '暫無可用寵物'),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
        ],
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
            '${_localization.getString(pet.name, defaultValue: pet.name)} ${_localization.getString('pets.upgrade_success', defaultValue: '升級成功！')}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _addTestPoints(Pet pet) async {
    await _petService.addUpgradePoints(pet.rarity, 1);
    if (!mounted) return;
    final updated = _petService.getPetByRarity(pet.rarity);
    if (updated == null) return;
    final need = updated.nextLevelRequirement;
    final has = updated.upgradePoints;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_localization.getString(updated.name, defaultValue: updated.name)} +1 (${_localization.getString('pets.upgrade_points', defaultValue: '升級點數')}: $has/$need)',
        ),
        backgroundColor: Colors.deepPurple,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }
}
