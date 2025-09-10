import 'dart:async';
import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/pet_tutorial_service.dart';
import 'package:idle_hippo/services/tutorial_focus_service.dart';

/// 寵物系統引導遮罩：高亮 focus 區域並限制點擊，其餘區域吸收點擊。
class PetTutorialOverlay extends StatefulWidget {
  const PetTutorialOverlay({super.key});

  @override
  State<PetTutorialOverlay> createState() => _PetTutorialOverlayState();
}

class _PetTutorialOverlayState extends State<PetTutorialOverlay> {
  final PetTutorialService _tutorial = PetTutorialService();
  final LocalizationService _i18n = LocalizationService();
  bool _showNext = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tutorial.initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextIfNeeded(int step) {
    // Step 1 與 Step 3 需等待 1 秒顯示 Next
    final needWait = (step == 1 || step == 3);
    if (!needWait || _showNext) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _showNext = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TutorialFocusService(),
      builder: (context, _) {
        return ValueListenableBuilder(
          valueListenable: _tutorial.state,
          builder: (context, st, _) {
            final step = st.step;
            if (st.completed || step == 0) return const SizedBox.shrink();

            _scheduleNextIfNeeded(step);
            // 退出需等待的步驟時，重置 Next 顯示狀態
            if (!(step == 1 || step == 3) && _showNext) {
              _timer?.cancel();
              _showNext = false;
            }

            // Step 4：沿用主教學的終章特效樣式，置中顯示獎勵文案
            if (step == 4) {
              final title = _i18n.getString(
                'tutorial.pet_ticket_reward',
                defaultValue: 'You received 10 Pet Gacha Tickets!',
              );
              final nextLabel = _i18n.getString(
                'tutorial.next',
                defaultValue: 'Next',
              );
              return Positioned.fill(
                child: _PetEpilogueOverlay(
                  title: title,
                  nextLabel: nextLabel,
                  onNext: () async {
                    await _tutorial.recordAction('btn_next');
                  },
                ),
              );
            }
            if (!(step == 1 || step == 2 || step == 3 || step == 4)) {
              return const SizedBox.shrink();
            }

            final key = _tutorial.currentInstructionKey ?? '';
            final focusId = _tutorial.currentFocusTargetId;
            final size = MediaQuery.of(context).size;

            Rect? calcFocusRect(String? id) {
              if (id == null) return null;
              final measured = TutorialFocusService().getRect(id);
              if (measured != null) return measured;
              switch (id) {
                case 'nav_pets':
                  return Rect.fromCenter(
                    center: Offset(size.width * 0.3, size.height - 70),
                    width: 110,
                    height: 110,
                  );
                case 'nav_home':
                  return Rect.fromCenter(
                    center: Offset(size.width * 0.5, size.height - 70),
                    width: 110,
                    height: 110,
                  );
                case 'home_pet_ticket':
                  return Rect.fromLTWH(
                    8,
                    MediaQuery.of(context).padding.top + 8 + 45 + 45,
                    220,
                    32,
                  );
                default:
                  return null;
              }
            }

            final hole = calcFocusRect(focusId);

            return Positioned.fill(
              child: Stack(
                children: [
                  if (hole != null) ...[
                    // 以四塊區域組合遮罩，保留中間可互動區域
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: hole.top,
                      child: const _AbsorbMask(),
                    ),
                    Positioned(
                      left: 0,
                      top: hole.top,
                      width: hole.left,
                      height: hole.height,
                      child: const _AbsorbMask(),
                    ),
                    Positioned(
                      left: hole.right,
                      right: 0,
                      top: hole.top,
                      height: hole.height,
                      child: const _AbsorbMask(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: hole.bottom,
                      bottom: 0,
                      child: const _AbsorbMask(),
                    ),
                  ] else ...[
                    Positioned.fill(child: const _AbsorbMask()),
                  ],

                  // 說明文字（nav 按鈕顯示在上方，其餘顯示在下方）
                  if (hole != null)
                    if (focusId == 'nav_pets' || focusId == 'nav_home')
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: (size.height - hole.top) + 2,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _i18n.getString(key, defaultValue: key),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: 0,
                        right: 0,
                        top: hole.bottom + 8,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _i18n.getString(key, defaultValue: key),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),

                  // Next 按鈕（step 1/3 等待後顯示；step 4 直接顯示以完成）
                  if ((step == 1 || step == 3) && _showNext)
                    if (focusId == 'nav_pets' || focusId == 'nav_home')
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: (size.height - (hole?.top ?? size.height)) + 2 + 10 + 40,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _tutorial.recordAction('btn_next');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE89A00),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _i18n.getString('tutorial.next', defaultValue: 'Next'),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (hole?.bottom ?? size.height * 0.5) + 56,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _tutorial.recordAction('btn_next');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE89A00),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _i18n.getString('tutorial.next', defaultValue: 'Next'),
                            ),
                          ),
                        ),
                      ),

                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AbsorbMask extends StatelessWidget {
  const _AbsorbMask();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(color: Colors.black.withValues(alpha: 0.7)),
    );
  }
}

/// 參考主教學的 Epilogue 視覺效果：置中霓虹卡片 + 掃描線背景
class _PetEpilogueOverlay extends StatefulWidget {
  final String title;
  final String nextLabel;
  final VoidCallback onNext;
  const _PetEpilogueOverlay({
    required this.title,
    required this.nextLabel,
    required this.onNext,
  });

  @override
  State<_PetEpilogueOverlay> createState() => _PetEpilogueOverlayState();
}

class _PetEpilogueOverlayState extends State<_PetEpilogueOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.7)),
        ),
        // 動態掃描線背景
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, -1 + 2 * t),
                    end: Alignment(0, 1 + 2 * t),
                    colors: [
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.02),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    tileMode: TileMode.mirror,
                  ),
                ),
              );
            },
          ),
        ),
        // 置中賽博卡片
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF00FFD1),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Color(0xFF6B7BD6),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
              border: Border.all(color: const Color(0xFF00FFD1), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(color: Color(0xFF00FFD1), blurRadius: 12),
                      Shadow(color: Color(0xFF6B7BD6), blurRadius: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE89A00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(
                        color: Color(0xFFFFD54F),
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
