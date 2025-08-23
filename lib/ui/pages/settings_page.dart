import 'package:flutter/material.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/page_manager.dart';
import 'package:idle_hippo/ui/pages/power_saver_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onLanguageChanged;
  final PageType previousPage;

  const SettingsPage({
    super.key,
    required this.onLanguageChanged,
    this.previousPage = PageType.home,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalizationService _localization = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 點擊外部時返回上一頁
        PageManager().navigateToPage(widget.previousPage);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {
              // 阻止點擊事件冒泡
            },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue, width: 2),
              ),

              child: Stack(
                children: [
                  // 關閉按鈕
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        PageManager().navigateToPage(widget.previousPage);
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '×',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,  // 從頂部開始對齊
                    crossAxisAlignment: CrossAxisAlignment.center,  // 保持水平居中
                    children: [
                      Text(
                        _localization.getPageName('settings'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _localization.getUI('language'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: LocalizationService.supportedLanguages.map((lang) {
                                final isSelected = _localization.currentLanguage == lang;
                                return GestureDetector(
                                  onTap: () async {
                                    await _localization.changeLanguage(lang);
                                    widget.onLanguageChanged();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.withOpacity(0.8)
                                          : Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? Colors.blue : Colors.grey,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      LocalizationService.languageNames[lang] ?? lang,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
