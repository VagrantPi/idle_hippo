import 'package:flutter/material.dart';

/// 顯示由上往下滑入的對話框
/// 用法：
/// await showTopSlideDialog(
///   context,
///   child: YourDialogContent(),
/// );
Future<T?> showTopSlideDialog<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x99000000), // 半透明背景
  Duration transitionDuration = const Duration(milliseconds: 500),
  Curve curve = Curves.easeOutCubic,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    pageBuilder: (context, anim1, anim2) {
      return SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, widget) {
      final curved = CurvedAnimation(parent: animation, curve: curve, reverseCurve: Curves.easeIn);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: widget,
        ),
      );
    },
  );
}

/// 方便包一層帶有圓角與背景的卡片樣式
class TopSlideDialogCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double elevation;
  final BorderRadiusGeometry borderRadius;
  final Color backgroundColor;

  const TopSlideDialogCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(top: 24, left: 16, right: 16),
    this.elevation = 8,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Card(
        elevation: elevation,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        color: backgroundColor,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
