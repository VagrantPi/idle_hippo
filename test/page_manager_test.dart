import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/page_manager.dart';

void main() {
  group('PageManager Tests', () {
    late PageManager pageManager;

    setUp(() {
      pageManager = PageManager();
      // 重置為首頁
      pageManager.navigateToPage(PageType.home);
    });

    test('should initialize with home page', () {
      expect(pageManager.currentPage, equals(PageType.home));
    });

    test('should change page correctly', () {
      pageManager.navigateToPage(PageType.equipment);
      expect(pageManager.currentPage, equals(PageType.equipment));
      
      pageManager.navigateToPage(PageType.pets);
      expect(pageManager.currentPage, equals(PageType.pets));
      
      pageManager.navigateToPage(PageType.shop);
      expect(pageManager.currentPage, equals(PageType.shop));
    });

    test('should notify listeners when page changes', () {
      bool listenerCalled = false;
      
      pageManager.addListener(() {
        listenerCalled = true;
      });
      
      pageManager.navigateToPage(PageType.equipment);
      expect(listenerCalled, isTrue);
    });

    test('should return correct localization keys for pages', () {
      expect(pageManager.getPageKey(PageType.home), equals('home'));
      expect(pageManager.getPageKey(PageType.equipment), equals('equipment'));
      expect(pageManager.getPageKey(PageType.pets), equals('pets'));
      expect(pageManager.getPageKey(PageType.shop), equals('shop'));
      expect(pageManager.getPageKey(PageType.titles), equals('titles'));
      expect(pageManager.getPageKey(PageType.quest), equals('quest'));
      expect(pageManager.getPageKey(PageType.settings), equals('settings'));
      expect(pageManager.getPageKey(PageType.musicGame), equals('musicGame'));
      expect(pageManager.getPageKey(PageType.noAds), equals('noAds'));
    });

    test('should return correct icon paths for pages', () {
      expect(pageManager.getPageIconPath(PageType.home), equals('assets/images/icon/Home.png'));
      expect(pageManager.getPageIconPath(PageType.equipment), equals('assets/images/icon/Equipment.png'));
      expect(pageManager.getPageIconPath(PageType.pets), equals('assets/images/icon/Pet.png'));
      expect(pageManager.getPageIconPath(PageType.shop), equals('assets/images/icon/Shop.png'));
      expect(pageManager.getPageIconPath(PageType.titles), equals('assets/images/icon/TitleBadge.png'));
      expect(pageManager.getPageIconPath(PageType.quest), equals('assets/images/icon/Quest.png'));
      expect(pageManager.getPageIconPath(PageType.settings), equals('assets/images/icon/Setting.png'));
      expect(pageManager.getPageIconPath(PageType.musicGame), equals('assets/images/icon/MusicGame.png'));
      expect(pageManager.getPageIconPath(PageType.noAds), equals('assets/images/icon/NOADS.png'));
    });

    test('should handle page navigation correctly', () {
      // 測試從首頁導航到其他頁面
      pageManager.navigateToPage(PageType.home);
      expect(pageManager.currentPage, equals(PageType.home));
      
      pageManager.navigateToPage(PageType.equipment);
      expect(pageManager.currentPage, equals(PageType.equipment));
      
      // 測試返回首頁
      pageManager.navigateToHome();
      expect(pageManager.currentPage, equals(PageType.home));
    });
  });
}
