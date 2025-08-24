import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';

class MainQuestBar extends StatefulWidget {
  final int progress;
  final int target;
  final VoidCallback? onTap;

  const MainQuestBar({
    super.key,
    required this.progress,
    required this.target,
    this.onTap,
  });

  @override
  State<MainQuestBar> createState() => _MainQuestBarState();
}

class _MainQuestBarState extends State<MainQuestBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainQuestBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress >= widget.target &&
        oldWidget.progress < oldWidget.target) {
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
    // 使用 defaultValue 以避免缺少語系字串時出錯
    return localization.getString(
      'mainquest.bar.title',
      defaultValue: '主線任務',
    );
  }

  Color _getAccentColor() {
    // 主色系：橘色
    return Colors.orange.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.progress >= widget.target;

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
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getAccentColor(),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getAccentColor().withValues(alpha: 0.3),
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
                      color: _getAccentColor(),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 標題文案
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
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 進度顯示
                  Text(
                    '${widget.progress}/${widget.target}',
                    style: TextStyle(
                      color: isCompleted ? Colors.orange.shade300 : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
