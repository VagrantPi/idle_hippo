import 'package:flutter/material.dart';

enum PageType {
  home,
  equipment,
  pets,
  shop,
  titles,
  quest,
  settings,
  checkin,
  musicGame,
  noAds,
  powerSaver,
}

class PageManager extends ChangeNotifier {
  static final PageManager _instance = PageManager._internal();
  factory PageManager() => _instance;
  PageManager._internal();

  final List<PageType> _pageStack = [PageType.home];

  PageType get currentPage => _pageStack.last;
  PageType? get previousPage =>
      _pageStack.length > 1 ? _pageStack[_pageStack.length - 2] : null;
  bool get isHomePage => currentPage == PageType.home;

  /// 切換到指定頁面
  void navigateToPage(PageType page, {bool isModal = false}) {
    if (currentPage == page) return;

    if (isModal) {
      // For modal pages, push to stack without removing previous
      _pageStack.add(page);
    } else {
      // For regular navigation, replace the top of stack
      if (_pageStack.isNotEmpty) {
        _pageStack.removeLast();
      }
      _pageStack.add(page);
    }

    notifyListeners();
  }

  /// 返回上一頁
  void navigateBack() {
    if (_pageStack.length > 1) {
      _pageStack.removeLast();
      notifyListeners();
    }
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
      case PageType.checkin:
        return 'checkin';
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
      case PageType.checkin:
        // 重用設定圖示，避免缺少資產導致錯誤
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
