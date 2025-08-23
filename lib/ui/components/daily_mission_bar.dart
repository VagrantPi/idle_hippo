import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';

class DailyMissionBar extends StatefulWidget {
  final String type; // 'tapX', 'accumulateX', 'completed'
  final int progress;
  final int target;
  final int? points; // 用於 accumulateX 的 {points} 參數
  final int? completedCount; // 今日已完成數量，用於顯示（x/10）
  final VoidCallback? onTap;

  const DailyMissionBar({
    super.key,
    required this.type,
    required this.progress,
    required this.target,
    this.points,
    this.completedCount,
    this.onTap,
  });

  @override
  State<DailyMissionBar> createState() => _DailyMissionBarState();
}

class _DailyMissionBarState extends State<DailyMissionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.blue.shade600,
      end: Colors.green.shade600,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DailyMissionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 當進度完成時播放動畫
    if (widget.progress >= widget.target && oldWidget.progress < oldWidget.target) {
      _playCompletionAnimation();
    }
  }

  void _playCompletionAnimation() {
    _animationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _animationController.reverse();
        }
      });
    });
  }

  String _getTitle() {
    final localization = LocalizationService();
    
    switch (widget.type) {
      case 'tapX':
        return localization.getString('mission.bar.title.tap', replacements: {
          'target': widget.target.toString(),
        });
      case 'accumulateX':
        return localization.getString('mission.bar.title.acc', replacements: {
          'points': widget.points?.toString() ?? widget.target.toString(),
        });
      case 'completed':
        return localization.getString('mission.bar.done_today');
      default:
        return '';
    }
  }

  Color _getProgressColor() {
    if (widget.type == 'completed') {
      return Colors.green.shade600;
    }
    
    if (widget.progress >= widget.target) {
      return Colors.green.shade600;
    }
    
    return Colors.blue.shade600;
  }

  IconData _getIcon() {
    switch (widget.type) {
      case 'tapX':
        return Icons.touch_app;
      case 'accumulateX':
        return Icons.trending_up;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.progress >= widget.target;
    final progressRatio = widget.target > 0 
        ? (widget.progress / widget.target).clamp(0.0, 1.0) 
        : 0.0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getProgressColor(),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getProgressColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 任務圖示
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getProgressColor(),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(),
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // 任務文案
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _getTitle(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${(widget.completedCount ?? 0).clamp(0, 10)}/10)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // 進度顯示
                  if (widget.type != 'completed') ...[
                    Text(
                      '${widget.progress}/${widget.target}',
                      style: TextStyle(
                        color: isCompleted ? Colors.green.shade300 : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                  ] else ...[
                    // 完成狀態顯示勾勾
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.green.shade300,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
