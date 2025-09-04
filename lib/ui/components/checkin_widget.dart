import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/checkin_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/localization_service.dart';
import '../../models/game_state.dart';

/// 打卡系統 UI 組件
class CheckinWidget extends StatefulWidget {
  const CheckinWidget({super.key});

  @override
  State<CheckinWidget> createState() => _CheckinWidgetState();
}

class _CheckinWidgetState extends State<CheckinWidget> {
  final CheckinService _checkinService = CheckinService();
  final LocalizationService _localization = LocalizationService();
  bool _isProcessingAd = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 打卡內容
          ..._buildCheckinContent(),
        ],
      ),
    );
  }

  List<Widget> _buildCheckinContent() {
    final checkinState = _checkinService.getCurrentCheckinState();
    if (checkinState == null) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          child: Text('打卡系統初始化中...', style: TextStyle(color: Colors.white70)),
        ),
      ];
    }

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 今日任務
            _buildTodayTask(checkinState.today),
            const SizedBox(height: 16),
            // 週曆
            _buildWeeklyCalendar(),
            const SizedBox(height: 16),
            // 連續統計
            _buildStreakInfo(checkinState.streak),
          ],
        ),
      ),
    ];
  }

  Widget _buildTodayTask(CheckinToday today) {
    final task = today.task;
    final progress = task.progress;
    final target = task.target;
    final progressPercent = target > 0
        ? (progress / target).clamp(0.0, 1.0)
        : 0.0;

    String taskDescription;
    if (task.type == 'tap') {
      taskDescription = _localization
          .getString('checkin.task.tap')
          .replaceAll('{n}', target.toString());
    } else {
      taskDescription = _localization
          .getString('checkin.task.collect')
          .replaceAll('{m}', target.toString());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: today.status == 'pending' ? Colors.orange : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.type == 'tap' ? Icons.touch_app : Icons.monetization_on,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  taskDescription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 進度條
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercent,
              child: Container(
                decoration: BoxDecoration(
                  color: today.status == 'pending'
                      ? Colors.orange
                      : Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$progress / $target',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Text(
                _localization.getString('checkin.status.${today.status}'),
                style: TextStyle(
                  color: today.status == 'pending'
                      ? Colors.orange
                      : Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // 按鈕區域
          if (today.status == 'pending') ...[
            const SizedBox(height: 12),
            // 看廣告跳過按鈕
            if (_checkinService.canSkipViaAd()) _buildAdSkipButton(),

            // 完成簽到按鈕
            const SizedBox(height: 8),
            _buildCompleteButton(
              isEnabled: _checkinService.canCompleteToday(),
              onPressed: _checkinService.canCompleteToday()
                  ? _handleComplete
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdSkipButton() {
    return GestureDetector(
      onTap: _isProcessingAd ? null : _handleAdSkip,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _isProcessingAd ? Colors.grey : Colors.purple,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: _isProcessingAd
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _localization.getString('checkin.btn.skip_ad'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton({
    bool isEnabled = true,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.green : Colors.grey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            _localization.getString('checkin.btn.complete'),
            style: TextStyle(
              color: isEnabled ? Colors.white : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    final calendar = _checkinService.getWeeklyCalendar();
    final dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localization.getString('checkin.weekly'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final isCompleted = calendar[index];
            final dayName = _localization.getString(
              'checkin.calendar.${dayNames[index]}',
            );

            return Column(
              children: [
                Text(
                  dayName,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStreakInfo(CheckinStreak streak) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStreakItem(
            _localization
                .getString('checkin.streak.current')
                .replaceAll('{n}', streak.current.toString()),
            streak.current.toString(),
            Colors.orange,
          ),
          _buildStreakItem(
            _localization
                .getString('checkin.streak.best')
                .replaceAll('{n}', streak.best.toString()),
            streak.best.toString(),
            Colors.yellow,
          ),
          _buildStreakItem(
            _localization
                .getString('checkin.streak.total')
                .replaceAll('{n}', streak.total.toString()),
            streak.total.toString(),
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.split('：')[0], // 取標籤部分
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _handleAdSkip() async {
    if (!_checkinService.canSkipViaAd()) {
      // 不可跳過時直接返回
      return;
    }

    setState(() {
      _isProcessingAd = true;
    });

    try {
      final rewarded = RewardedAdService();
      await rewarded.showAd(
        context: context,
        onAdWatched: () async {
          await _checkinService.skipViaAd();
        },
        dialogTitle: _localization.getString(
          'checkin.ad.success_title',
          defaultValue: 'Check-in Completed',
        ),
        rewardContent: Text(
          _localization.getString(
            'checkin.ad.success_desc',
            defaultValue: 'You have completed today\'s check-in.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        showSuccessDialog: false,
      );

      if (!mounted) return;
      setState(() {
        _isProcessingAd = false;
      });

      // 顯示簽到完成動畫
      _showCheckinCompleteAnimation();
    } catch (e) {
      if (kDebugMode) {
        log('Ad skip failed: $e');
      }
      if (mounted) {
        setState(() {
          _isProcessingAd = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('廣告播放失敗，請稍後再試'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleComplete() async {
    if (!_checkinService.canCompleteToday()) {
      return; // 防止重複點擊
    }

    try {
      // 僅在達標後由使用者主動完成簽到
      await _checkinService.completeToday();
      if (!mounted) return;
      // 立即刷新 UI 狀態（顯示已完成/週曆等）
      setState(() {});

      // 顯示簽到完成動畫
      if (mounted) {
        _showCheckinCompleteAnimation();
      }
    } catch (e) {
      if (kDebugMode) {
        log('簽到失敗: $e');
      }
      if (mounted) {
        // 顯示錯誤提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('簽到失敗，請稍後再試'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCheckinCompleteAnimation() {
    // 使用 showGeneralDialog 顯示短暫酷炫動畫（無需額外相依）
    final rnd = math.Random();
    // 預先取得 NavigatorState，避免在延遲後直接使用 context（跨 async gap）
    final navigator = Navigator.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'checkin-animation',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final scale = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        ).value;
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut).value;

        // 生成少量紙花星星
        List<Widget> sparkles = List.generate(10, (i) {
          final angle = (i / 10.0) * 2 * math.pi;
          final dist = (40 + rnd.nextInt(30)).toDouble() * anim.value;
          final dx = dist * math.cos(angle);
          final dy = dist * math.sin(angle);
          final size = 6.0 + rnd.nextDouble() * 10.0;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: fade * (0.6 + rnd.nextDouble() * 0.4),
              child: Icon(
                Icons.star_rounded,
                color: Colors.amberAccent,
                size: size,
              ),
            ),
          );
        });

        return Stack(
          children: [
            // 中央放大徽章
            Center(
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: fade,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 背景放射光暈
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        // 星星粒子
                        ...sparkles,
                        // 勾勾圖示
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 84,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // 自動關閉動畫彈層
    Future.delayed(const Duration(milliseconds: 850), () {
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }
}
