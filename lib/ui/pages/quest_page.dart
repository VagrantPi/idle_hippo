import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/config_service.dart';

class QuestPage extends StatelessWidget {
  final List<Map<String, dynamic>> missionPlan;
  final int missionsTodayCompleted;
  final VoidCallback? onClaimCurrentMission;

  const QuestPage({
    super.key,
    this.missionPlan = const [],
    this.missionsTodayCompleted = 0,
    this.onClaimCurrentMission,
  });

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();

    String titleForItem(String type, String pointsOrTarget) {
      if (type == 'tapX') {
        // 以 {target} 動態替換，顯示與 game.json daily_mission.tap_target 一致
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localization.getString('mission.dailyMissions', defaultValue: '每日任務') + (' (${missionsTodayCompleted}/10)'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: 10,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = (index < missionPlan.length)
                    ? missionPlan[index]
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
                    color: Colors.black.withOpacity(0.5),
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
                                  // 只有 locked 的累積任務隱藏數字；done 與 current 顯示保存/凍結的數字
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
                            onPressed: canClaim ? onClaimCurrentMission : null,
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
        ],
      ),
    );
  }
}
