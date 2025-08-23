import 'package:flutter/material.dart';

enum PageType {
  home,
  equipment,
  pets,
  shop,
  titles,
  quest,
  settings,
  musicGame,
  noAds,
  powerSaver,
}

class PageManager extends ChangeNotifier {
  static final PageManager _instance = PageManager._internal();
  factory PageManager() => _instance;
  PageManager._internal();

  PageType _currentPage = PageType.home;
  PageType? _previousPage;
  
  PageType get currentPage => _currentPage;
  PageType? get previousPage => _previousPage;
  bool get isHomePage => _currentPage == PageType.home;

  /// 切換到指定頁面
  void navigateToPage(PageType page) {
    if (_currentPage == page) return;
    
    _previousPage = _currentPage;
    _currentPage = page;
    notifyListeners();
    print('PageManager: Navigated to ${page.name}');
  }

  /// 回到主頁
  void navigateToHome() {
    navigateToPage(PageType.home);
  }

  /// 取得頁面對應的本地化鍵值
  String getPageKey(PageType page) {
    switch (page) {
      case PageType.home:
        return 'home';
      case PageType.equipment:
        return 'equipment';
      case PageType.pets:
        return 'pets';
      case PageType.shop:
        return 'shop';
      case PageType.titles:
        return 'titles';
      case PageType.quest:
        return 'quest';
      case PageType.settings:
        return 'settings';
      case PageType.musicGame:
        return 'musicGame';
      case PageType.noAds:
        return 'noAds';
      case PageType.powerSaver:
        return 'powerSaver';
    }
  }

  /// 取得頁面對應的圖示路徑
  String getPageIconPath(PageType page) {
    switch (page) {
      case PageType.home:
        return 'assets/images/icon/Home.png';
      case PageType.equipment:
        return 'assets/images/icon/Equipment.png';
      case PageType.pets:
        return 'assets/images/icon/Pet.png';
      case PageType.shop:
        return 'assets/images/icon/Shop.png';
      case PageType.titles:
        return 'assets/images/icon/TitleBadge.png';
      case PageType.quest:
        return 'assets/images/icon/Quest.png';
      case PageType.settings:
        return 'assets/images/icon/Setting.png';
      case PageType.musicGame:
        return 'assets/images/icon/MusicGame.png';
      case PageType.noAds:
        return 'assets/images/icon/NOADS.png';
      case PageType.powerSaver:
        return 'assets/images/icon/PowerSaver.png';
    }
  }
}
