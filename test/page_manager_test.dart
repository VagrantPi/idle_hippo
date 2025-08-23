import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/page_manager.dart';

void main() {
  group('PageManager 測試', () {
    late PageManager pageManager;

    setUp(() {
      pageManager = PageManager();
      // 重置為首頁
      pageManager.navigateToPage(PageType.home);
    });

    test('應以首頁初始化', () {
      expect(pageManager.currentPage, equals(PageType.home));
    });

    test('應可正確切換頁面', () {
      pageManager.navigateToPage(PageType.equipment);
      expect(pageManager.currentPage, equals(PageType.equipment));
      
      pageManager.navigateToPage(PageType.pets);
      expect(pageManager.currentPage, equals(PageType.pets));
      
      pageManager.navigateToPage(PageType.shop);
      expect(pageManager.currentPage, equals(PageType.shop));
    });

    test('頁面變更時應通知監聽者', () {
      bool listenerCalled = false;
      
      pageManager.addListener(() {
        listenerCalled = true;
      });
      
      pageManager.navigateToPage(PageType.equipment);
      expect(listenerCalled, isTrue);
    });

    test('應回傳正確的頁面本地化鍵', () {
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

    test('應回傳正確的頁面圖示路徑', () {
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

    test('應能正確處理頁面導航', () {
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
