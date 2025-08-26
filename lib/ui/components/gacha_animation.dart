import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:idle_hippo/services/gacha_service.dart';
import 'package:idle_hippo/models/pet.dart';
import 'package:idle_hippo/services/localization_service.dart';

class GachaAnimationDialog extends StatefulWidget {
  final List<GachaResult> results;
  final VoidCallback onComplete;
  final ValueChanged<GachaResult>? onReveal;
  // 使用者按「下一個/確定」時觸發，傳遞當前已揭示之結果
  final ValueChanged<GachaResult>? onAdvance;

  const GachaAnimationDialog({
    super.key,
    required this.results,
    required this.onComplete,
    this.onReveal,
    this.onAdvance,
  });

  @override
  State<GachaAnimationDialog> createState() => _GachaAnimationDialogState();
}

class _GachaAnimationDialogState extends State<GachaAnimationDialog>
    with TickerProviderStateMixin {
  late AnimationController _cardController;
  late AnimationController _glowController;
  late AnimationController _textController;
  late Animation<double> _cardAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _textAnimation;
  final LocalizationService _localization = LocalizationService();
  
  int _currentIndex = 0;
  bool _showResult = false;
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();
    
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.bounceOut,
    ));

    _startAnimation();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _glowController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startAnimation() async {
    setState(() {
      _canSkip = false;
      _showResult = false;
    });

    // 卡片翻轉動畫
    await _cardController.forward();
    
    // 延遲顯示結果
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      _showResult = true;
      _canSkip = true;
    });
    // 通知：當前卡片揭示（顯示名稱時）
    if (widget.onReveal != null) {
      widget.onReveal!(widget.results[_currentIndex]);
    }

    // 光效動畫
    _glowController.repeat(reverse: true);
    
    // 文字彈出動畫
    await _textController.forward();
    // 移除自動前進，改為等待使用者按「下一個」
  }

  void _nextCard() {
    if (_currentIndex < widget.results.length - 1) {
      // 通知：使用者選擇前往下一張，釋放當前結果
      if (widget.onAdvance != null) {
        widget.onAdvance!(widget.results[_currentIndex]);
      }
      setState(() {
        _currentIndex++;
        _showResult = false;
        _canSkip = false;
      });
      
      _cardController.reset();
      _glowController.reset();
      _textController.reset();
      
      _startAnimation();
    } else {
      _finish();
    }
  }

  void _skipAnimation() {
    if (_canSkip) {
      _cardController.stop();
      _glowController.stop();
      _textController.stop();
      
      setState(() {
        _showResult = true;
        _currentIndex = widget.results.length - 1;
      });
      
      Future.delayed(const Duration(milliseconds: 500), _finish);
    }
  }

  void _finish() {
    // 通知：最後一張按下「確定」，釋放最後結果
    if (widget.onAdvance != null) {
      widget.onAdvance!(widget.results[_currentIndex]);
    }
    Navigator.of(context).pop();
    widget.onComplete();
  }

  Color _getRarityColor(PetRarity rarity) {
    switch (rarity) {
      case PetRarity.ssr:
        return Colors.amber;
      case PetRarity.sr:
        return Colors.purple;
      case PetRarity.s:
        return Colors.blue;
      case PetRarity.r:
        return Colors.green;
      case PetRarity.rr:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.results[_currentIndex];
    final rarityColor = _getRarityColor(result.rarity);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // 背景星空效果
            _buildStarField(),
            
            // 主要內容
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 進度指示器
                if (widget.results.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 20),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.results.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                
                // 卡片動畫區域
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _cardAnimation,
                      builder: (context, child) {
                        // 兩階段：
                        // 1) 先做一個完整 360° 旋轉（僅顯示背面）
                        // 2) 再做原本的 180° 翻面（過半才顯示正面並內旋 180° 矯正）
                        const double spinPhase = 2.0 / 3.0; // 前 2/3 時間用於 360°
                        final double t = _cardAnimation.value;
                        double angle;
                        bool showFront;

                        if (t < spinPhase) {
                          final double p = t / spinPhase; // 0..1
                          angle = p * 2 * math.pi; // 0..360°
                          showFront = false;
                        } else {
                          final double p = (t - spinPhase) / (1 - spinPhase); // 0..1
                          angle = 2 * math.pi + p * math.pi; // 360° + 0..180°
                          showFront = p >= 0.5;
                        }

                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          child: showFront
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(math.pi),
                                  child: _buildCardFront(result, rarityColor),
                                )
                              : _buildCardBack(),
                        );
                      },
                    ),
                  ),
                ),
                
                // 操作按鈕
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_canSkip)
                        ElevatedButton(
                          onPressed: _skipAnimation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.3),
                          ),
                          child: Text(
                            _localization.getString('pets.gacha.skip', defaultValue: 'Skip'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      
                      if (_showResult)
                        ElevatedButton(
                          onPressed: _currentIndex < widget.results.length - 1 
                              ? _nextCard 
                              : _finish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rarityColor.withValues(alpha: 0.7),
                          ),
                          child: Text(
                            _currentIndex < widget.results.length - 1
                                ? _localization.getString('pets.gacha.next', defaultValue: 'Next')
                                : _localization.getString('pets.gacha.confirm', defaultValue: 'OK'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomPaint(
        painter: StarFieldPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withValues(alpha: 0.3),
            Colors.purple.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.help_outline,
          size: 80,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCardFront(GachaResult result, Color rarityColor) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _showResult ? rarityColor : Colors.white30, width: 3),
            boxShadow: [
              BoxShadow(
                color: _showResult
                    ? rarityColor.withValues(alpha: 0.5 + _glowAnimation.value * 0.3)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: _showResult ? (20 + _glowAnimation.value * 10) : 8,
                spreadRadius: _showResult ? (5 + _glowAnimation.value * 3) : 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // 稀有度標籤
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _showResult ? rarityColor : Colors.white24,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  result.rarity.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _showResult ? Colors.white : Colors.transparent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              
              // 寵物圖片/名稱區塊
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: _showResult
                            ? Image.asset(
                                result.imagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.pets,
                                    size: 80,
                                    color: rarityColor,
                                  );
                                },
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 寵物名稱（結果揭示後才顯示）
                      if (_showResult)
                        AnimatedBuilder(
                          animation: _textAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.8 + _textAnimation.value * 0.2,
                              child: Text(
                                result.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: rarityColor,
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // 新獲得標籤
                      if (result.isNew && _showResult)
                        AnimatedBuilder(
                          animation: _textAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _textAnimation.value,
                              child: Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _localization.getString('pets.gacha.new_pet', defaultValue: 'New!'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // 繪製隨機星星
    for (int i = 0; i < 50; i++) {
      final x = (i * 37) % size.width;
      final y = (i * 73) % size.height;
      final opacity = ((i * 17) % 100) / 100.0;
      
      paint.color = Colors.white.withValues(alpha: opacity * 0.8);
      canvas.drawCircle(Offset(x, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
