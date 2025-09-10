import 'dart:async';
import 'package:flutter/material.dart';
import 'package:idle_hippo/services/tutorial_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/tutorial_focus_service.dart';

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final TutorialService _tutorial = TutorialService();
  final LocalizationService _i18n = LocalizationService();
  bool _showNext = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // lazy init (ignore await)
    _tutorial.initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildInstruction(String key) {
    final text = _i18n.getString(key, defaultValue: key);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildManga(int page) {
    final index = page.clamp(1, 4);
    final path = 'assets/images/manga/manga0$index.png';
    return GestureDetector(
      onTap: () async {
        final progressed = await _tutorial.advanceManga();
        if (!progressed) {
          await _tutorial.finishMangaIfReady();
        }
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 400,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  // 淡入 + 由右至左輕微滑入
                  final slide = Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Image.asset(
                  path,
                  key: ValueKey(path),
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.image_not_supported,
                    size: 120,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildInstruction('tutorial.manga'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TutorialFocusService(),
      builder: (context, __) {
        return ValueListenableBuilder(
          valueListenable: _tutorial.state,
          builder: (context, st, _) {
            final step = st.step;
            if (st.completed) return const SizedBox.shrink();

            // Special handling: manga (auto-start on step 0), and step 1
            if (step == 0 || step == 1) {
              final page = (step == 0)
                  ? 1
                  : (st.mangaPage == 0 ? 1 : st.mangaPage);
              return Positioned.fill(child: _buildManga(page));
            }

            // Step 4 / 8 / 9 / 11 / 13: show next after 1s
            if ((step == 4 ||
                    step == 8 ||
                    step == 9 ||
                    step == 11 ||
                    step == 13) &&
                !_showNext) {
              _timer?.cancel();
              _timer = Timer(const Duration(seconds: 1), () {
                if (mounted) setState(() => _showNext = true);
              });
            } else if (step != 4 &&
                step != 8 &&
                step != 9 &&
                step != 11 &&
                step != 13 &&
                _showNext) {
              // reset flag when leaving these steps
              _showNext = false;
            }

            final key = _tutorial.currentInstructionKey ?? '';
            final focusId = _tutorial.currentFocusTargetId;
            final size = MediaQuery.of(context).size;

            Rect? calcFocusRect(String? id) {
              if (id == null) return null;
              final paddingTop = MediaQuery.of(context).padding.top + 8;
              final measured = TutorialFocusService().getRect(id);
              if (measured != null) return measured;
              switch (id) {
                case 'mainline_title':
                  // 未量測到時，退回為畫面上方中段的大區塊
                  return Rect.fromLTWH(
                    16,
                    paddingTop + 120,
                    size.width - 32,
                    160,
                  );
                case 'panel_meme_points':
                  // 左上資源面板 fallback 區域
                  return Rect.fromLTWH(8, paddingTop + 45 + 8, 220, 64);
                case 'btn_upgrade_youtube':
                  // 若無量測資料，退回畫面右半部中段
                  return Rect.fromLTWH(
                    size.width * 0.5,
                    size.height * 0.35,
                    size.width * 0.45,
                    size.height * 0.3,
                  );
                case 'hippo':
                  final w = size.width * 0.6;
                  return Rect.fromCenter(
                    center: Offset(size.width * 0.5, size.height * 0.5),
                    width: w,
                    height: w,
                  );
                case 'btn_settings':
                  return Rect.fromLTWH(
                    size.width - 16 - 50,
                    paddingTop,
                    50,
                    50,
                  );
                case 'btn_mainline':
                  return Rect.fromLTWH(
                    size.width - 8 - 80,
                    size.height * 0.4,
                    80,
                    80,
                  );
                case 'btn_daily_quests':
                  return Rect.fromLTWH(
                    size.width - 8 - 80,
                    size.height * 0.4,
                    80,
                    80,
                  );
                case 'nav_home':
                  return Rect.fromCenter(
                    center: Offset(size.width * 0.5, size.height - 70),
                    width: 110,
                    height: 110,
                  );
                default:
                  return null;
              }
            }

            final hole = (step >= 2 && step <= 12)
                ? calcFocusRect(focusId)
                : null;

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
                      child: _AbsorbMask(),
                    ),
                    Positioned(
                      left: 0,
                      top: hole.top,
                      width: hole.left,
                      height: hole.height,
                      child: _AbsorbMask(),
                    ),
                    Positioned(
                      left: hole.right,
                      right: 0,
                      top: hole.top,
                      height: hole.height,
                      child: _AbsorbMask(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: hole.bottom,
                      bottom: 0,
                      child: _AbsorbMask(),
                    ),
                    // 說明文字（不擋點擊）：
                    // - 若 focus 在 nav（nav_home），文字顯示在挖空上方 2px
                    // - 其他步驟顯示在挖空下方 2px
                    if (focusId == 'nav_home')
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: (size.height - hole.top) + 2,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Center(child: _buildInstruction(key)),
                        ),
                      )
                    else
                      Positioned(
                        left: 0,
                        right: 0,
                        top: hole.bottom + 2,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Center(child: _buildInstruction(key)),
                        ),
                      ),
                    // Next 按鈕（僅 wait-then-next 與 step14 顯示）：
                    // 非 nav：顯示在說明之下 10px；nav：顯示在說明之上 10px
                    if (((step == 4 ||
                                step == 8 ||
                                step == 9 ||
                                step == 11 ||
                                step == 13) &&
                            _showNext) ||
                        step == 14)
                      if (focusId == 'nav_home')
                        Positioned(
                          left: 0,
                          right: 0,
                          // 估計說明高度 ~40，因此將按鈕放在說明上方 10px
                          bottom: (size.height - hole.top) + 2 + 10 + 40,
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
                                _i18n.getString(
                                  'tutorial.next',
                                  defaultValue: 'Next',
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          left: 0,
                          right: 0,
                          // 估計說明高度 ~40，因此將按鈕放在說明下方 10px
                          top: hole.bottom + 2 + 10 + 40,
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
                                _i18n.getString(
                                  'tutorial.next',
                                  defaultValue: 'Next',
                                ),
                              ),
                            ),
                          ),
                        ),
                  ] else ...[
                    // 無法推算焦點位置時，回退為可擋點擊的全屏遮罩
                    Positioned.fill(child: _AbsorbMask()),
                    if (step == 13) ...[
                      _EpilogueCyberOverlay(
                        title: _i18n.getString(
                          'tutorial.epilogue',
                          defaultValue:
                              'This is the beginning of Hippo\'s legend',
                        ),
                        nextLabel: _i18n.getString(
                          'tutorial.next',
                          defaultValue: 'Next',
                        ),
                        showNext: _showNext,
                        onNext: () async {
                          await _tutorial.recordAction('btn_next');
                        },
                      ),
                    ] else ...[
                      // 其他步驟維持底部說明
                      IgnorePointer(
                        ignoring: true,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 140),
                            child: _buildInstruction(key),
                          ),
                        ),
                      ),
                    ],
                  ],
                  // 若沒有 hole（尚未量測成功），退回底部顯示橘色 Next 按鈕
                  if ((((step == 4 || step == 8 || step == 9 || step == 11) &&
                              _showNext) ||
                          step == 14) &&
                      hole == null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 80),
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
                            _i18n.getString(
                              'tutorial.next',
                              defaultValue: 'Next',
                            ),
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
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(color: Colors.black.withValues(alpha: 0.5)),
    );
  }
}

// 專屬 Step 13 的賽博龐克風格覆蓋層
class _EpilogueCyberOverlay extends StatefulWidget {
  final String title;
  final String nextLabel;
  final bool showNext;
  final VoidCallback onNext;

  const _EpilogueCyberOverlay({
    required this.title,
    required this.nextLabel,
    required this.showNext,
    required this.onNext,
  });

  @override
  State<_EpilogueCyberOverlay> createState() => _EpilogueCyberOverlayState();
}

class _EpilogueCyberOverlayState extends State<_EpilogueCyberOverlay>
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
                // 霓虹標題
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
                // 霓虹 Next 按鈕
                if (widget.showNext)
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
                  )
                else
                  const SizedBox(height: 44),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
