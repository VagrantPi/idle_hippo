import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:idle_hippo/ui/components/daily_cap_progress_bar.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/page_manager.dart';
import 'package:idle_hippo/ui/components/animated_button.dart';
import 'package:idle_hippo/ui/components/plus_meme_particle.dart';
import 'package:idle_hippo/ui/pages/equipment_page.dart';
import 'package:idle_hippo/ui/pages/pets_page.dart';
import 'package:idle_hippo/ui/pages/shop_page.dart';
import 'package:idle_hippo/ui/pages/titles_page.dart';
import 'package:idle_hippo/ui/pages/quest_page.dart';
import 'package:idle_hippo/ui/pages/settings_page.dart';
import 'package:idle_hippo/ui/pages/music_game_page.dart';
import 'package:idle_hippo/ui/pages/no_ads_page.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

class MainScreen extends StatefulWidget {
  final double memePoints;
  final Map<String, int> equipments;

  final VoidCallback onCharacterTap;
  final int Function()? onCharacterTapWithResult; // optional: returns gained points
  final int dailyCapTodayGained;
  final int dailyCapEffective;
  final bool adDoubledToday;
  final VoidCallback? onAdDouble;
  final void Function(String id)? onEquipmentUpgrade;
  final void Function(String id)? onIdleEquipmentUpgrade;
  final VoidCallback? onToggleDebug; // optional: toggle debug panel from parent
  final double? lastTapDisplayValue; // optional: display base+bonus value for particle
  final double? displayMemePoints; // optional: for UI display only (includes fractional idle accumulation)

  const MainScreen({
    super.key,
    required this.memePoints,
    this.equipments = const {},
    required this.onCharacterTap,
    this.onCharacterTapWithResult,
    this.dailyCapTodayGained = 0,
    this.dailyCapEffective = 200,
    this.adDoubledToday = false,
    this.onAdDouble,
    this.onEquipmentUpgrade,
    this.onIdleEquipmentUpgrade,
    this.onToggleDebug,
    this.lastTapDisplayValue,
    this.displayMemePoints,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final LocalizationService _localization = LocalizationService();
  final PageManager _pageManager = PageManager();
  
  late AnimationController _characterController;
  late final IdleIncomeService _idleIncome;
  late Animation<double> _characterScaleAnimation;
  late AnimationController _swingController;
  late Animation<double> _swingAnimation;
  late AnimationController _randomMoveController;
  late Animation<Offset> _randomMoveAnimation;
  final math.Random _random = math.Random();

  final List<Widget> _particles = [];
  static const int _maxParticles = 10;

  String _formatNumber(num value) {
    final v = value.toDouble();
    if (v.abs() >= 1e9) return (v / 1e9).toStringAsFixed(1) + 'B';
    if (v.abs() >= 1e6) return (v / 1e6).toStringAsFixed(1) + 'M';
    if (v.abs() >= 1e3) return (v / 1e3).toStringAsFixed(1) + 'K';
    // 對於迷因點數顯示，只保留一位小數以避免過多小數位
    return v.toStringAsFixed(1);
  }

  // 速率顯示（/s）使用整數顯示：例如 0.1 -> '0', 1.9 -> '2'
  String _formatPerSecond(num value) {
    return value.toDouble().toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _idleIncome = IdleIncomeService();

    _characterController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _characterScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _characterController,
      curve: Curves.easeOut,
    ));

    // 添加搖擺動畫控制器
    _swingController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);
    
    // 設置左右各1度的搖擺動畫
    _swingAnimation = Tween<double>(
      begin: -0.5 * (3.1415927 / 180), // 轉換為弧度
      end: 0.5 * (3.1415927 / 180),    // 轉換為弧度
    ).animate(CurvedAnimation(
      parent: _swingController,
      curve: Curves.easeInOut,
    ));

    // 添加隨機移動動畫控制器
    _randomMoveController = AnimationController(
      duration: Duration(seconds: _random.nextInt(3) + 2),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _setupRandomMoveAnimation();
        }
      });

    _setupRandomMoveAnimation();

    // 監聽頁面切換
    _pageManager.addListener(_onPageChanged);
  }


  // 在 _MainScreenState 類別中添加這個變數
  Offset _currentOffset = Offset.zero;

  void _setupRandomMoveAnimation() {
    // 生成新的目標位置（相對於當前位置）
    final targetOffset = Offset(
      _random.nextDouble() * 160 - 80, // -80 到 80 之間
      _random.nextDouble() * 160 - 80, // -80 到 80 之間
    );

    _randomMoveAnimation = Tween<Offset>(
      begin: _currentOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _randomMoveController,
      curve: Curves.easeInOut,
    ));

    _currentOffset = targetOffset;
    
    _randomMoveController.forward(from: 0);
  }

  @override
  void dispose() {
    _swingController.dispose();
    _randomMoveController.dispose();
    _characterController.dispose();
    _pageManager.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    setState(() {});
  }

  void _onCharacterTapped() {
    // 播放角色壓感動畫
    _characterController.forward().then((_) {
      _characterController.reverse();
    });

    // 觸發遊戲邏輯（若提供帶回傳版本則優先使用）
    int gained = 0;
    if (widget.onCharacterTapWithResult != null) {
      gained = widget.onCharacterTapWithResult!();
    } else {
      widget.onCharacterTap();
      gained = 1; // 舊版預設視為成功以維持舊行為
    }

    // 僅在實際加分時生成粒子
    if (gained > 0) {
      _generateParticle(gained);
    }
  }

  void _generateParticle(num gained) {
    if (_particles.length >= _maxParticles) {
      // 移除最舊的粒子
      setState(() {
        _particles.removeAt(0);
      });
    }

    // 計算角色位置和隨機生成位置
    final screenSize = MediaQuery.of(context).size;
    final characterCenterX = screenSize.width * 0.5;
    final characterCenterY = screenSize.height * 0.5;
    final characterRadius = screenSize.width * 0.3; // 角色寬度的 50%

    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final distance = random.nextDouble() * characterRadius;
    
    final particleX = characterCenterX + math.cos(angle) * distance;
    final particleY = characterCenterY + math.sin(angle) * distance;

    final particleKey = UniqueKey();
    final displayValue = (widget.lastTapDisplayValue != null && widget.lastTapDisplayValue! > 0)
        ? widget.lastTapDisplayValue!
        : gained;
    final particle = PlusMemeParticle(
      key: particleKey,
      startPosition: Offset(particleX, particleY),
      onComplete: () {
        setState(() {
          _particles.removeWhere((p) => p.key == particleKey);
        });
      },
      baseValue: displayValue,
    );

    setState(() {
      _particles.add(particle);
    });
  }

  Widget _buildBackground() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: AnimatedOpacity(
        opacity: _pageManager.isHomePage ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: Image.asset(
          'assets/images/background/Base.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.blue[100],
              child: const Center(
                child: Text('Background Image Missing'),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDebugToggle() {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: 8,
      top: size.height / 2 - 24,
      child: GestureDetector(
        onTap: () => widget.onToggleDebug?.call(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
          ),
          child: const Icon(
            Icons.bug_report,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCharacter() {
    return Center(
      child: GestureDetector(
        onTap: _pageManager.isHomePage ? _onCharacterTapped : null,
        child: AnimatedBuilder(
          animation: _characterController,
          builder: (context, child) {
            return Transform.scale(
              scale: _characterScaleAnimation.value,
              child: AnimatedOpacity(
                opacity: _pageManager.isHomePage ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 150),
                child: AnimatedBuilder(
                  animation: _randomMoveAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: _randomMoveAnimation.value,
                      child: RotationTransition(
                        turns: _swingAnimation,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/images/character/HippoBase.png',
                          width: MediaQuery.of(context).size.width * 0.7,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: MediaQuery.of(context).size.width * 0.6,
                              height: MediaQuery.of(context).size.width * 0.6,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orange, width: 3),
                              ),
                              child: const Icon(
                                Icons.pets,
                                size: 60,
                                color: Colors.orange,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailyCapDisplay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: Container(
        constraints: const BoxConstraints(minWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 進度條（獨立元件）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 使用擴展以填滿可用寬度
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: DailyCapProgressBar(
                    current: widget.dailyCapTodayGained.toDouble(),
                    max: widget.dailyCapEffective.toDouble(),
                    height: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.dailyCapEffective - widget.dailyCapTodayGained} / ${widget.dailyCapEffective}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceDisplay() {
    return Positioned(
      // 放在日常點數顯示之下，避免重疊
      top: MediaQuery.of(context).padding.top + 8 + 45,
      left: 8,
      child: Container(
        constraints: const BoxConstraints(minWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 迷因點數區塊
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _localization.getCommon('memePoints'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatPerSecond(_idleIncome.currentIdlePerSec)} ${_localization.getCommon('perSecond')}',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatNumber(widget.displayMemePoints ?? widget.memePoints),
                    textAlign: TextAlign.right,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSideButtons() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      left: 8,
      child: AnimatedButton(
        iconPath: 'assets/images/icon/NOADS.png',
        onTap: () => _pageManager.navigateToPage(PageType.noAds),
        size: 80,
      ),
    );
  }

  Widget _buildTopRightSideButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 8,
      child: AnimatedButton(
        iconPath: 'assets/images/icon/Setting.png',
        onTap: () => _pageManager.navigateToPage(PageType.settings),
        size: 50,
      ),
    );
  }

  Widget _buildRightSideButtons() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      right: 8,
      child: Column(
        children: [
          const SizedBox(height: 16),
          AnimatedButton(
            iconPath: 'assets/images/icon/Quest.png',
            onTap: () => _pageManager.navigateToPage(PageType.quest),
            size: 80,
          ),
          const SizedBox(height: 16),
          AnimatedButton(
            iconPath: 'assets/images/icon/MusicGame.png',
            onTap: () => _pageManager.navigateToPage(PageType.musicGame),
            size: 70,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Positioned(
      top: MediaQuery.of(context).size.height - 120,
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          color: const Color(0xFF2B0A56),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(
              iconPath: 'assets/images/icon/TitleBadge.png',
              pageType: PageType.titles,
            ),
            _buildNavButton(
              iconPath: 'assets/images/icon/Pet.png',
              pageType: PageType.pets,
            ),
            _buildNavButton(
              iconPath: 'assets/images/icon/Home.png',
              isHome: true,
            ),
            _buildNavButton(
              iconPath: 'assets/images/icon/Equipment.png',
              pageType: PageType.equipment,
            ),
            _buildNavButton(
              iconPath: 'assets/images/icon/Shop.png',
              pageType: PageType.shop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required String iconPath,
    PageType? pageType,
    bool isHome = false,
  }) {
    final isSelected = isHome
        ? _pageManager.isHomePage
        : _pageManager.currentPage == pageType;

    final containerWidth = isSelected ? 90.0 : 70.0;

    // 獲取按鈕標題
    String getButtonTitle() {
      if (isHome) return _localization.getPageName('home');
      switch (pageType) {
        case PageType.titles:
          return _localization.getPageName('titles');
        case PageType.pets:
          return _localization.getPageName('pets');
        case PageType.equipment:
          return _localization.getPageName('equipment');
        case PageType.shop:
          return _localization.getPageName('shop');
        default:
          return '';
      }
    }

    final bottomNavigationBarHeight = isSelected ? MediaQuery.of(context).size.height / 14 + 20: MediaQuery.of(context).size.height / 14;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: containerWidth,
      height: bottomNavigationBarHeight,
      alignment: Alignment.center,
      child: AnimatedButton(
        iconPath: iconPath,
        size: bottomNavigationBarHeight.toDouble(), // 調整按鈕大小
        isNavButton: true,
        showTitle: isSelected,
        title: getButtonTitle(),
        onTap: () {
          if (isHome) {
            _pageManager.navigateToHome();
          } else if (pageType != null) {
            _pageManager.navigateToPage(pageType);
          }
        },
        borderColor: isSelected 
            ? const Color(0xFF00FFD1)
            : const Color(0xFF6B7BD6),
        borderWidth: 2,
      ),
    );
  }

  Widget _buildCurrentPage() {
    // 使用 Offstage 來隱藏/顯示頁面，而不是重新構建
    return Stack(
      children: [
        // 主頁內容
        Offstage(
          offstage: !_pageManager.isHomePage,
          child: const SizedBox.shrink(),
        ),
        
        // 其他頁面內容
        ..._buildPageContent(),
      ],
    );
  }

  List<Widget> _buildPageContent() {
    if (_pageManager.isHomePage) return [];
    
    Widget pageContent;
    switch (_pageManager.currentPage) {
      case PageType.equipment:
        pageContent = EquipmentPage(
          memePoints: widget.memePoints,
          equipments: widget.equipments,
          onUpgrade: widget.onEquipmentUpgrade ?? (_){},
          onUpgradeIdle: widget.onIdleEquipmentUpgrade ?? (_){},
        );
        break;
      case PageType.pets:
        pageContent = const PetsPage();
        break;
      case PageType.shop:
        pageContent = const ShopPage();
        break;
      case PageType.titles:
        pageContent = const TitlesPage();
        break;
      case PageType.quest:
        pageContent = const QuestPage();
        break;
      case PageType.settings:
        pageContent = SettingsPage(
          onLanguageChanged: () => setState(() {}),
          previousPage: _pageManager.previousPage ?? PageType.home,
        );
        break;
      case PageType.musicGame:
        pageContent = const MusicGamePage();
        break;
      case PageType.noAds:
        pageContent = const NoAdsPage();
        break;
      default:
        return [];
    }
    
    return [
      Offstage(
        offstage: _pageManager.isHomePage,
        child: pageContent,
      )
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景
          _buildBackground(),
          
          // 當前頁面內容
          _buildCurrentPage(),
          
          // 只在首頁顯示的元素
          if (_pageManager.isHomePage) ...[
            // 角色
            _buildCharacter(),
            
            // 粒子特效
            ..._particles,
            
            // 左側按鈕
            _buildLeftSideButtons(),
            
            // 右側按鈕
            _buildRightSideButtons(),
            
            // 日常點數顯示
            _buildDailyCapDisplay(),

            // 資源顯示
            _buildResourceDisplay(),
          ],
          
          // 始終顯示的元素
          // 右上角按鈕
          _buildTopRightSideButtons(),
          
          // 底部導航欄
          _buildBottomNavigation(),

          // 左側 y 軸中心 Debug 切換按鈕
          _buildDebugToggle(),
        ],
      ),
    );
  }
}
