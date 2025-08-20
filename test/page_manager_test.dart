import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/page_manager.dart';

void main() {
  group('PageManager Tests', () {
    late PageManager pageManager;

    setUp(() {
      pageManager = PageManager.instance;
      // 重置為首頁
      pageManager.setCurrentPage(PageType.home);
    });

    test('should initialize with home page', () {
      expect(pageManager.currentPage, equals(PageType.home));
    });

    test('should change page correctly', () {
      pageManager.setCurrentPage(PageType.equipment);
      expect(pageManager.currentPage, equals(PageType.equipment));
      
      pageManager.setCurrentPage(PageType.pets);
      expect(pageManager.currentPage, equals(PageType.pets));
      
      pageManager.setCurrentPage(PageType.shop);
      expect(pageManager.currentPage, equals(PageType.shop));
    });

    test('should notify listeners when page changes', () {
      bool listenerCalled = false;
      
      pageManager.addListener(() {
        listenerCalled = true;
      });
      
      pageManager.setCurrentPage(PageType.equipment);
      expect(listenerCalled, isTrue);
    });

    test('should return correct localization keys for pages', () {
      expect(PageManager.getPageLocalizationKey(PageType.home), equals('home'));
      expect(PageManager.getPageLocalizationKey(PageType.equipment), equals('equipment'));
      expect(PageManager.getPageLocalizationKey(PageType.pets), equals('pets'));
      expect(PageManager.getPageLocalizationKey(PageType.shop), equals('shop'));
      expect(PageManager.getPageLocalizationKey(PageType.titles), equals('titles'));
      expect(PageManager.getPageLocalizationKey(PageType.quest), equals('quest'));
      expect(PageManager.getPageLocalizationKey(PageType.musicGame), equals('music_game'));
      expect(PageManager.getPageLocalizationKey(PageType.noAds), equals('no_ads'));
    });

    test('should return correct icon paths for pages', () {
      expect(PageManager.getPageIconPath(PageType.home), equals('assets/images/icon/home.png'));
      expect(PageManager.getPageIconPath(PageType.equipment), equals('assets/images/icon/equipment.png'));
      expect(PageManager.getPageIconPath(PageType.pets), equals('assets/images/icon/pets.png'));
      expect(PageManager.getPageIconPath(PageType.shop), equals('assets/images/icon/shop.png'));
      expect(PageManager.getPageIconPath(PageType.titles), equals('assets/images/icon/titles.png'));
    });

    test('should handle page navigation correctly', () {
      // 測試從首頁導航到其他頁面
      pageManager.setCurrentPage(PageType.home);
      expect(pageManager.currentPage, equals(PageType.home));
      
      pageManager.setCurrentPage(PageType.equipment);
      expect(pageManager.currentPage, equals(PageType.equipment));
      
      // 測試返回首頁
      pageManager.setCurrentPage(PageType.home);
      expect(pageManager.currentPage, equals(PageType.home));
    });
  });
}
