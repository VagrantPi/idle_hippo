import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlusMemeParticle extends StatefulWidget {
  final Offset startPosition;
  final VoidCallback onComplete;
  final num baseValue;

  const PlusMemeParticle({
    super.key,
    required this.startPosition,
    required this.onComplete,
    this.baseValue = 0,
  });

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

  // 實作千分位，固定顯示兩位小數（包含 K/M/B），例如 12.34K, 0.12, 12.34, 12.34M, 12.34B
  String _formatNumber(num value) {
    final v = value.toDouble();
    if (v.abs() >= 1e9) return (v / 1e9).toStringAsFixed(2) + 'B';
    if (v.abs() >= 1e6) return (v / 1e6).toStringAsFixed(2) + 'M';
    if (v.abs() >= 1e3) return (v / 1e3).toStringAsFixed(2) + 'K';
    return v.toStringAsFixed(2);
  }

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
                scale: _scaleAnimation.value * 0.5, // 整體縮小 50%
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/icon/PlusMemePoint.png',
                      width: 30, // 保持原始尺寸，透過 Transform.scale * 0.5 達到 50%
                      height: 30,
                      errorBuilder: (context, error, stackTrace) {
                        // 載入失敗時顯示替代圖示
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 32,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatNumber(widget.baseValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
