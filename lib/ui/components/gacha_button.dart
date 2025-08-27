import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';

class GachaButton extends StatefulWidget {
  final String text;
  final String costText;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final Color primaryColor;
  final IconData icon;

  const GachaButton({
    super.key,
    required this.text,
    required this.costText,
    required this.onPressed,
    required this.isEnabled,
    this.primaryColor = Colors.blue,
    this.icon = Icons.casino,
  });

  @override
  State<GachaButton> createState() => _GachaButtonState();
}

class _GachaButtonState extends State<GachaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.isEnabled ? widget.onPressed : null,
            child: Container(
              width: double.infinity,
              height: 80,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isEnabled
                      ? [
                          widget.primaryColor,
                          widget.primaryColor.withValues(alpha: 0.7),
                        ]
                      : [
                          Colors.grey.withValues(alpha: 0.5),
                          Colors.grey.withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isEnabled
                      ? widget.primaryColor.withValues(alpha: 0.8)
                      : Colors.grey.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: widget.isEnabled
                    ? [
                        BoxShadow(
                          color: widget.primaryColor.withValues(
                            alpha: 0.3 + _glowAnimation.value * 0.2,
                          ),
                          blurRadius: 8 + _glowAnimation.value * 4,
                          spreadRadius: 2 + _glowAnimation.value * 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // 圖示區域
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  
                  // 文字區域
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: widget.isEnabled 
                                ? Colors.white 
                                : Colors.grey.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.costText,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isEnabled 
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.grey.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 箭頭指示器
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: widget.isEnabled 
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.grey.withValues(alpha: 0.5),
                      size: 20,
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

class TicketDisplay extends StatelessWidget {
  final int ticketCount;
  final Color backgroundColor;
  final Color textColor;

  const TicketDisplay({
    super.key,
    required this.ticketCount,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: backgroundColor.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number,
            color: textColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '${LocalizationService().getString('pets.ticket', defaultValue: 'Tickets')}: $ticketCount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class GachaHistoryCard extends StatelessWidget {
  final String rarity;
  final String name;
  final int timestamp;
  final Color rarityColor;

  const GachaHistoryCard({
    super.key,
    required this.rarity,
    required this.name,
    required this.timestamp,
    required this.rarityColor,
  });

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '剛剛';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分鐘前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小時前';
    } else {
      return '${difference.inDays}天前';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 稀有度標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rarityColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              rarity,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 寵物名稱
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 時間
          Text(
            _formatTime(timestamp),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
