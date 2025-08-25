import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/main_quest_service.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/pet_ticket_quest_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';
import 'package:idle_hippo/ui/components/slide_in_dialog.dart';

class QuestPage extends StatefulWidget {
  final List<Map<String, dynamic>> missionPlan;
  final int missionsTodayCompleted;
  final VoidCallback? onClaimCurrentMission;
  final VoidCallback? onClaimCurrentStage;
  final GameState gameState;
  final int initialTabIndex;
  // 新增：寵物抽獎券領取回調，讓父層更新全域 GameState
  final void Function(bool withAd)? onPetTicketClaim;

  const QuestPage({
    super.key,
    this.missionPlan = const [],
    this.missionsTodayCompleted = 0,
    this.onClaimCurrentMission,
    this.onClaimCurrentStage,
    required this.gameState,
    this.initialTabIndex = 0,
    this.onPetTicketClaim,
  });

  @override
  State<QuestPage> createState() => _QuestPageState();
}

class _QuestPageState extends State<QuestPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MainQuestService _mainQuest = MainQuestService();
  final PetTicketQuestService _petTicketQuest = PetTicketQuestService();
  final IdleIncomeService _idleIncome = IdleIncomeService();
  late GameState _state;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: idx);
    _state = widget.gameState;
    // 讓 IdleIncomeService 知道目前的 GameState（用於計算 idlePerSec）
    _idleIncome.updateGameState(_state);
    // 檢查解鎖並生成第一個寵物抽獎券任務
    _initializePetTicketQuest();
  }

  @override
  void didUpdateWidget(covariant QuestPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父層 GameState 變更時，同步本地 _state，避免顯示不同步
    if (!identical(oldWidget.gameState, widget.gameState)) {
      setState(() {
        _state = widget.gameState;
        _idleIncome.updateGameState(_state);
        // 重新檢查寵物抽獎券任務解鎖與首次任務生成
        _initializePetTicketQuest();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            localization.getString('pages.quest', defaultValue: '任務'),
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
                Tab(text: localization.getString('mission.dailyMissions', defaultValue: '每日任務')),
                Tab(text: localization.getString('quest.main_quest', defaultValue: '主線任務')),
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
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyMissionsTab(localization),
                _buildMainQuestTab(localization),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _initializePetTicketQuest() {
    // 解鎖
    var gs = _petTicketQuest.checkAndUnlock(_state);
    // 僅在「已解鎖且尚未有目標（target<=0）」時生成第一個任務目標
    final quest = gs.petTicketQuest;
    if (quest != null && quest.available && quest.target <= 0) {
      final idle = _idleIncome.currentIdlePerSec;
      gs = _petTicketQuest.generateFirstQuest(gs, currentIdlePerSec: idle);
    }
    _state = gs;
  }

  Widget _buildDailyMissionsTab(LocalizationService localization) {
    String titleForItem(String type, String pointsOrTarget) {
      if (type == 'tapX') {
        return localization.getString(
          'mission.bar.title.tap',
          replacements: {'target': pointsOrTarget},
          defaultValue: 'TAP',
        );
      }
      return localization.getString(
        'mission.bar.title.acc',
        replacements: {'points': pointsOrTarget},
        defaultValue: '累積',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 寵物抽獎券任務卡片（顯示於每日任務上方）
        _buildPetTicketQuestCard(localization),
        const SizedBox(height: 12),
        Text(
          localization.getString('mission.dailyMissions', defaultValue: '每日任務') + (' (${widget.missionsTodayCompleted}/10)'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 移除多餘留白
        const SizedBox(height: 0),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: 10,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
              final item = (index < widget.missionPlan.length)
                  ? widget.missionPlan[index]
                  : {
                      'index': index + 1,
                      'type': (index + 1) % 2 == 1 ? 'tapX' : 'accumulateX',
                      'target': (index + 1) % 2 == 1
                          ? (ConfigService().getValue('game.daily_mission.tap_target', defaultValue: 50) as num).toInt()
                          : 0,
                      'progress': 0,
                      'status': 'locked',
                    };
              final status = item['status'] as String? ?? 'locked';
              final locked = status == 'locked';
              final current = status == 'current';
              final done = status == 'done';
              final idx = item['index'] ?? (index + 1);
              final type = item['type'] as String? ?? 'tapX';
              final target = (item['target'] as num?)?.toInt() ?? 0;
              final progress = (item['progress'] as num?)?.toInt() ?? 0;
              final reward = (item['reward'] as num?)?.toInt() ?? 0;
              final displayPoints = item['displayPoints']?.toString() ?? target.toString();
              final canClaim = current && progress >= target && !done;

              final baseTile = Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: done
                        ? const Color(0xFF00FFD1)
                        : (current ? const Color(0xFFE89A00) : Colors.white24),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: current
                          ? const Color(0xFFE89A00)
                          : (done ? const Color(0xFF00FFD1) : Colors.white24),
                      child: Text(
                        '$idx',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleForItem(type, displayPoints),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                (type == 'accumulateX' && status == 'locked')
                                    ? '—'
                                    : '$progress / $target',
                                style: TextStyle(
                                  color: done ? const Color(0xFF00FFD1) : Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+$reward',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (done)
                      const Icon(Icons.check_circle, color: Color(0xFF00FFD1))
                    else if (current)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: canClaim ? widget.onClaimCurrentMission : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canClaim ? const Color(0xFFE89A00) : Colors.grey,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(LocalizationService().getString('ui.claim', defaultValue: '領取')),
                        ),
                      )
                      
                    else
                      const Icon(Icons.lock, color: Colors.white38),
                  ],
                ),
              );

                return AbsorbPointer(
                  absorbing: locked,
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: locked ? 0.6 : 1.0,
                        child: baseTile,
                      ),
                      if (locked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPetTicketQuestCard(LocalizationService localization) {
    final quest = _state.petTicketQuest;
    // 未解鎖或尚未產生目標則不顯示
    if (quest == null || !quest.available || quest.target <= 0) {
      return const SizedBox.shrink();
    }

    final progress = quest.progress;
    final target = quest.target;
    final done = progress >= target && target > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE89A00), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/icon/Lottery.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.confirmation_num, color: Colors.cyanAccent, size: 20);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localization.getString('pets.quest.ticket.title', defaultValue: '寵物抽獎券任務'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (done) const Icon(Icons.check_circle, color: Color(0xFF00FFD1))
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${localization.getString('pets.quest.ticket.desc', defaultValue: '累積點數')} ${progress.floor()} / ${target.floor()}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: done
                      ? () {
                          if (widget.onPetTicketClaim != null) {
                            widget.onPetTicketClaim!(false);
                          } else {
                            // 後備方案：若父層未提供回調，仍以本地狀態更新
                            setState(() {
                              _state = _petTicketQuest.claimReward(
                                _state,
                                withAd: false,
                                currentIdlePerSec: _idleIncome.currentIdlePerSec,
                              );
                              _idleIncome.updateGameState(_state);
                            });
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: done ? const Color(0xFFE89A00) : Colors.grey,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text('${localization.getString('ui.claim', defaultValue: '領取')} +1'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: done
                      ? () async {
                          print('claim pet ticket quest (x2) pressed, parent callback: ${widget.onPetTicketClaim != null}');
                          final localization = LocalizationService();
                          final dialogTitle = localization.getString('offline.title', defaultValue: 'Offline Reward');
                          final doubleLabel = localization.getString('offline.double_reward', defaultValue: 'Double x2');
                          final confirm = localization.getString('offline.confirm', defaultValue: 'Claim');

                          showTopSlideDialog(
                            context,
                            barrierDismissible: false,
                            child: Builder(
                              builder: (ctx) {
                                final theme = Theme.of(ctx);
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xCC110022),
                                        Color(0xCC2B0A56),
                                      ],
                                    ),
                                    border: Border.all(color: const Color(0xFF00FFD1).withValues(alpha: 0.8), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00FFD1).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF00FFD1), width: 1),
                                            ),
                                            child: const Icon(Icons.timer, color: Color(0xFF00FFD1)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              dialogTitle,
                                              style: theme.textTheme.titleLarge?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.confirmation_num, color: Colors.yellow, size: 20),
                                            const SizedBox(width: 6),
                                            Text(
                                              '+2',
                                              style: theme.textTheme.headlineSmall?.copyWith(
                                                color: Colors.yellow,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              localization.getString('pets.ticket', defaultValue: '抽獎券'),
                                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.yellowAccent),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            height: 44,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.slow_motion_video, size: 20),
                                              label: Text(doubleLabel),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFE89A00),
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () async {
                                                Navigator.of(ctx).pop();
                                                // 模擬觀看廣告流程（與 OfflineRewardService 一致：等待 3 秒）
                                                await Future.delayed(const Duration(seconds: 3));
                                                // 翻倍領取 + 顯示通知
                                                if (widget.onPetTicketClaim != null) {
                                                  // 交由父層進行 withAd:true 的領取與存檔
                                                  widget.onPetTicketClaim!(true);
                                                } else {
                                                  // 後備：本地更新
                                                  setState(() {
                                                    _state = _petTicketQuest.claimReward(
                                                      _state,
                                                      withAd: true,
                                                      currentIdlePerSec: _idleIncome.currentIdlePerSec,
                                                    );
                                                    _idleIncome.updateGameState(_state);
                                                  });
                                                }

                                                final successTitle = localization.getString('offline.doubled_success', defaultValue: 'Reward Doubled!');
                                                final ok = localization.getString('offline.confirm', defaultValue: 'Claim');
                                                showTopSlideDialog(
                                                  context,
                                                  barrierDismissible: true,
                                                  child: Builder(
                                                    builder: (ctx2) {
                                                      final theme2 = Theme.of(ctx2);
                                                      return GestureDetector(
                                                        onTap: () => Navigator.of(ctx2).pop(),
                                                        child: Container(
                                                          margin: const EdgeInsets.symmetric(horizontal: 24),
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(16),
                                                            gradient: const LinearGradient(
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                              colors: [
                                                                Color(0xCC113300),
                                                                Color(0xCC1F5E1F),
                                                              ],
                                                            ),
                                                            border: Border.all(color: const Color(0xFF00FFD1).withValues(alpha: 0.8), width: 2),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withValues(alpha: 0.5),
                                                                blurRadius: 16,
                                                                offset: const Offset(0, 8),
                                                              ),
                                                            ],
                                                          ),
                                                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    width: 36,
                                                                    height: 36,
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(0xFF00FFD1).withValues(alpha: 0.15),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                      border: Border.all(color: const Color(0xFF00FFD1), width: 1),
                                                                    ),
                                                                    child: const Icon(Icons.check_circle, color: Color(0xFF00FFD1)),
                                                                  ),
                                                                  const SizedBox(width: 12),
                                                                  Expanded(
                                                                    child: Text(
                                                                      successTitle,
                                                                      style: theme2.textTheme.titleLarge?.copyWith(
                                                                        color: Colors.white,
                                                                        fontWeight: FontWeight.w700,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 12),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.black.withValues(alpha: 0.35),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                                                ),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                                  children: [
                                                                    const Icon(Icons.confirmation_num, color: Colors.yellow, size: 20),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                      '+2',
                                                                      style: theme2.textTheme.headlineSmall?.copyWith(
                                                                        color: Colors.yellow,
                                                                        fontWeight: FontWeight.w800,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                      localization.getString('pets.ticket', defaultValue: '抽獎券'),
                                                                      style: theme2.textTheme.titleMedium?.copyWith(color: Colors.yellowAccent),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(height: 16),
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.end,
                                                                children: [
                                                                  SizedBox(
                                                                    width: 120,
                                                                    height: 44,
                                                                    child: ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: const Color(0xFF1F5E1F),
                                                                        foregroundColor: Colors.white,
                                                                        elevation: 0,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(12),
                                                                          side: const BorderSide(color: Color(0xFF00FFD1), width: 2),
                                                                        ),
                                                                      ),
                                                                      onPressed: () => Navigator.of(ctx2).pop(),
                                                                      child: Text(
                                                                        ok,
                                                                        style: theme2.textTheme.titleMedium?.copyWith(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.w700,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 120,
                                            height: 44,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2B0A56),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: const BorderSide(color: Color(0xFF00FFD1), width: 2),
                                                ),
                                              ),
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: Text(
                                                confirm,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        }
                  : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: done ? const Color(0xFF00FFD1) : Colors.grey,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: 
                  Row(
                    children: [
                      Icon(Icons.slow_motion_video, size: 20),
                      Text('${localization.getString('ui.claim', defaultValue: '領取')} x2'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainQuestTab(LocalizationService localization) {
    final questList = _mainQuest.getQuestList(_state);
    final stats = _mainQuest.getStats(_state);
    final currentStage = (stats['currentStage'] as int?) ?? 1;
    final requirementType = stats['requirementType'] as String?;
    final progressText = stats['progressText']?.toString() ?? '0';
    final targetText = stats['targetText']?.toString() ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            '${localization.getString('quest.main_quest', defaultValue: '主線任務')} ($currentStage/6)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 進度總覽
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE89A00), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localization.getString('quest.current_stage', replacements: {'n': '$currentStage'}, defaultValue: '目前階段 $currentStage'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (requirementType == 'tap_count')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.getString('quest.requirement.title.tap', defaultValue: '累積點擊次數'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '$progressText / $targetText',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else if (requirementType == 'meme_points')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.getString('quest.requirement.title.meme', defaultValue: '累積迷因點數'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '$progressText / $targetText',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // 移除統計卡片與清單之間的留白
        const SizedBox(height: 10),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: questList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quest = questList[index];
                final stage = (quest['stage'] as int?) ?? (index + 1);
                final status = quest['status'] as String? ?? 'locked';
                final isCompleted = status == 'completed';
                final isCurrent = status == 'current';
                final progressVal = (quest['progress'] as double?) ?? 0.0;
                final canClaimCurrent = isCurrent && progressVal >= 1.0;
                final reqType = quest['requirementType'] as String? ?? 'tap_count';
                final itemProgressText = quest['progressText']?.toString() ?? '0';
                final itemTargetText = quest['targetText']?.toString() ?? '0';
                final reward = (quest['reward'] as Map<String, dynamic>?);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF00FFD1)
                          : (isCurrent ? const Color(0xFFE89A00) : Colors.white24),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isCurrent
                                ? const Color(0xFFE89A00)
                                : (isCompleted ? const Color(0xFF00FFD1) : Colors.white24),
                            child: Text(
                              '$stage',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localization.getString('quest.stage$stage.title', defaultValue: 'Stage $stage'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isCompleted)
                            const Icon(Icons.check_circle, color: Color(0xFF00FFD1))
                          else if (isCurrent)
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: canClaimCurrent
                                  ? () {
                                      if (widget.onClaimCurrentStage != null) {
                                        widget.onClaimCurrentStage!();
                                      } else {
                                        setState(() {
                                          _state = _mainQuest.claimCurrentQuest(_state);
                                        });
                                      }
                                    }
                                  : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canClaimCurrent ? const Color(0xFFE89A00) : Colors.grey,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: Text(localization.getString('quest.completed.confirm', defaultValue: '確認')),
                              ),
                            )
                          else
                            const Icon(Icons.lock, color: Colors.white38),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 需求顯示（擇一）
                      Text(
                        reqType == 'tap_count'
                            ? localization.getString(
                                'quest.requirement.text.tap',
                                replacements: {
                                  'progress': itemProgressText,
                                  'target': itemTargetText,
                                },
                                defaultValue: '需求：點擊 $itemProgressText / $itemTargetText 次',
                              )
                            : localization.getString(
                                'quest.requirement.text.meme',
                                replacements: {
                                  'progress': itemProgressText,
                                  'target': itemTargetText,
                                },
                                defaultValue: '需求：累積 $itemProgressText / $itemTargetText 迷因點數',
                              ),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      // 獎勵顯示
                      Text(
                        (localization.getString('quest.reward.label', defaultValue: '獎勵：')) +
                            (reward == null
                                ? localization.getString('quest.reward.none', defaultValue: '—')
                                : _getRewardDisplayText(localization, reward)),
                        style: const TextStyle(color: Color(0xFFE89A00), fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getRewardDisplayText(LocalizationService localization, Map<String, dynamic> reward) {
    final type = reward['type'] as String;
    final id = reward['id'] as String;
    
    switch (type) {
      case 'idle':
        return localization.getString('quest.reward.idle', 
            replacements: {'rewardId': id}, defaultValue: '解鎖放置裝備：$id');
      case 'equipment':
        return localization.getString('quest.reward.equipment', 
            replacements: {'rewardId': id}, defaultValue: '解鎖 $id 裝備');
      case 'system':
        if (id == 'title') {
          return localization.getString('quest.reward.title_system', defaultValue: '解鎖稱號系統');
        } else if (id == 'pet') {
          return localization.getString('quest.reward.pet_system', defaultValue: '解鎖寵物系統');
        }
        return localization.getString('quest.reward.system', 
            replacements: {'rewardId': id}, defaultValue: '解鎖 $id 系統');
      case 'skin':
        return localization.getString('quest.reward.skin', 
            replacements: {'rewardId': id}, defaultValue: '解鎖新造型：$id');
      default:
        return localization.getString('quest.reward.unknown', defaultValue: '神秘獎勵');
    }
  }
}
