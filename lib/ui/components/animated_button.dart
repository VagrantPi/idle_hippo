import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final String iconPath;
  final VoidCallback onTap;
  final double size;
  final bool isNavButton;
  final bool showTitle;  // 新增：是否顯示標題
  final String? title;   // 新增：標題文字
  final Color? borderColor;
  final double borderWidth;

  const AnimatedButton({
    super.key,
    required this.iconPath,
    required this.onTap,
    this.size = 48.0,
    this.isNavButton = false,
    this.showTitle = false,
    this.title,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleXAnimation;
  late Animation<double> _scaleYAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    if (widget.isNavButton) {
      // 下方導航按鈕：左右放大動畫
      _scaleXAnimation = Tween<double>(
        begin: 1.0,
        end: 1.5,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));

      _scaleYAnimation = Tween<double>(
        begin: 1.0,
        end: 0.98,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
    } else {
      // 其他按鈕：一般縮放動畫
      _scaleXAnimation = Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));

      _scaleYAnimation = _scaleXAnimation;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: widget.isNavButton ? MediaQuery.of(context).size.width / 5 : widget.size + (widget.showTitle ? 24 : 0),
            height: widget.isNavButton ? kBottomNavigationBarHeight * 2 : widget.size + (widget.showTitle ? 36 : 0),
            alignment: Alignment.center,
            decoration: widget.isNavButton && widget.borderColor != null
                ? BoxDecoration(
                    border: Border.all(
                      color: widget.borderColor!,
                      width: widget.borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Transform.scale(
              scaleX: _scaleXAnimation.value,
              scaleY: _scaleYAnimation.value,
              child: Container(
                width: widget.isNavButton ? null : widget.size,
                height: widget.isNavButton ? null : widget.size,
                padding: widget.isNavButton ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : null,
                decoration: !widget.isNavButton
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: widget.borderColor != null 
                            ? Border.all(
                                color: widget.borderColor!,
                                width: widget.borderWidth,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Image.asset(
                        widget.iconPath,
                        width: 300,
                        // width: widget.isNavButton ? widget.size * 0.6 : widget.size * 0.8,
                        // height: widget.isNavButton ? widget.size * 0.6 : widget.size * 0.8,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (widget.showTitle && widget.title != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          widget.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
