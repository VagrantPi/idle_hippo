import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlusMemeParticle extends StatefulWidget {
  final Offset startPosition;
  final VoidCallback onComplete;

  const PlusMemeParticle({
    Key? key,
    required this.startPosition,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<PlusMemeParticle> createState() => _PlusMemeParticleState();
}

class _PlusMemeParticleState extends State<PlusMemeParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  late double _targetY;
  late double _duration;

  @override
  void initState() {
    super.initState();
    
    // 隨機化動畫參數
    final random = math.Random();
    _targetY = widget.startPosition.dy - (40 + random.nextDouble() * 40); // -40 到 -80
    _duration = 1 + random.nextDouble() * 1.5; // 0.6 到 0.8 秒
    
    _controller = AnimationController(
      duration: Duration(milliseconds: (_duration * 1000).round()),
      vsync: this,
    );

    // 上飄動畫
    _moveAnimation = Tween<double>(
      begin: widget.startPosition.dy,
      end: _targetY,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // 淡出動畫
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // 縮放動畫
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startPosition.dx - 24, // 圖片寬度的一半
          top: _moveAnimation.value - 24, // 圖片高度的一半
          child: IgnorePointer( // 粒子不阻擋點擊
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Image.asset(
                  'assets/images/icon/PlusMemePoint.png',
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    // 載入失敗時顯示替代圖示
                    return Container(
                      width: 60,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
