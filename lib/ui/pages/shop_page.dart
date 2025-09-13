import 'package:flutter/material.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/store_service.dart';
import 'package:idle_hippo/services/rewarded_ad_service.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _config = ConfigService();
  final _i18n = LocalizationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Preload store purchase counts.
    StoreService().initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _i18n.getPageName('shop'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(
                  'permanent',
                  const PageStorageKey('shop_tab_permanent'),
                ),
                _buildTabContent(
                  'limited',
                  const PageStorageKey('shop_tab_limited'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            text: _i18n.getString(
              'store.tab.permanent',
              defaultValue: 'Permanent',
            ),
          ),
          Tab(
            text: _i18n.getString('store.tab.limited', defaultValue: 'Limited'),
          ),
        ],
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: const Color(0xFF00FFD1),
        labelStyle: const TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildTabContent(String tabKey, PageStorageKey storageKey) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;
    final List<dynamic> sections =
        _config.getValue('store.tabs.$tabKey', defaultValue: const <dynamic>[])
            as List<dynamic>;

    return ListView.builder(
      key: storageKey,
      padding: EdgeInsets.only(bottom: bottomPad),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final sec = sections[index] as Map<String, dynamic>;
        final sectionKey = (sec['section_key'] ?? '') as String;
        final items = (sec['items'] ?? const <dynamic>[]) as List<dynamic>;
        if (items.isEmpty) return const SizedBox.shrink();
        final isPermanent = tabKey == 'permanent';
        return _buildSection(
          sectionKey,
          items.cast<String>(),
          isPermanent: isPermanent,
        );
      },
    );
  }

  Widget _buildSection(
    String sectionKey,
    List<String> itemKeys, {
    bool isPermanent = false,
  }) {
    final children = <Widget>[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _i18n.getString(sectionKey, defaultValue: sectionKey),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];

    // 注意：items 的鍵包含點號（例如 'store.card_click_perm'），
    // 不能用 getValue('store.items.$key') 取值，需整包取出後以原鍵索引。
    final itemsMap = _config.getValue('store.items') as Map<String, dynamic>?;
    if (itemsMap != null) {
      for (final key in itemKeys) {
        final raw = itemsMap[key];
        final data = (raw is Map<String, dynamic>) ? raw : null;
        if (data == null) continue;
        children.add(_StoreCard(itemKey: key, data: data));
      }
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    if (isPermanent) {
      // 將整個分組包在灰底容器中（含標題與所有 items）
      content = Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
          child: content,
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: content,
      );
    }

    return content;
  }
}

class _StoreCard extends StatelessWidget {
  final String itemKey;
  final Map<String, dynamic> data;
  const _StoreCard({required this.itemKey, required this.data});

  @override
  Widget build(BuildContext context) {
    final i18n = LocalizationService();

    // 名稱與描述：若提供 i18n 鍵，優先使用；否則回退到 JSON 內字串
    String resolveText(dynamic obj) {
      if (obj is String) return obj;
      if (obj is Map<String, dynamic>) {
        final lang = i18n.currentLanguage;
        final v = obj[lang] ?? obj['en'] ?? obj['zh'];
        if (v is String) return v;
      }
      return '';
    }

    // 新方案：優先使用 i18n key -> 預設 key -> 舊結構回退
    final String providedNameKey = (data['name_key'] ?? '') as String;
    final String providedDescKey = (data['desc_key'] ?? '') as String;
    final String defaultNameKey = 'store.items.$itemKey.name';
    final String defaultDescKey = 'store.items.$itemKey.desc';

    String name = '';
    if (providedNameKey.isNotEmpty) {
      name = i18n.getString(providedNameKey, defaultValue: '');
    }
    if (name.isEmpty) {
      name = i18n.getString(defaultNameKey, defaultValue: '');
    }
    if (name.isEmpty) {
      name = resolveText(data['name']);
    }

    String desc = '';
    if (providedDescKey.isNotEmpty) {
      desc = i18n.getString(providedDescKey, defaultValue: '');
    }
    if (desc.isEmpty) {
      desc = i18n.getString(defaultDescKey, defaultValue: '');
    }
    if (desc.isEmpty) {
      desc = resolveText(data['desc']);
    }
    final image = (data['image'] ?? '') as String;
    final limitType = (data['purchase_limit_type'] ?? '') as String;
    final adsPay = (data['ads_pay'] ?? false) as bool;

    final badgeText = _badgeText(i18n, limitType);
    final int maxCount = (data['purchase_max_count'] is int)
        ? (data['purchase_max_count'] as int)
        : 1;
    final store = StoreService();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // 避免父層攔截手勢，讓內部購買按鈕可點擊
          onTap: null,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左側圖片
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: SizedBox(
                        width: 108,
                        height: 108,
                        child: _StoreCardImage(imagePath: image),
                      ),
                    ),
                    // 右側文字
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedBuilder(
                              animation: store,
                              builder: (context, _) {
                                final currentCount = store.getCount(itemKey);
                                final bool isLimited = limitType == 'limited';
                                final bool isUnlimited =
                                    limitType == 'unlimited';
                                final bool isDaily = limitType == 'daily';
                                final bool isMonthly = limitType == 'monthly';
                                final bool isFirst7 = limitType == 'first7';
                                final bool isFirst30 = limitType == 'first30';
                                final bool canBuyLimited =
                                    isLimited && currentCount < maxCount;
                                final bool canBuyDaily = isDaily
                                    ? store.canPurchaseDaily(itemKey, maxCount)
                                    : false;
                                final bool canBuyMonthly = isMonthly
                                    ? store.canPurchaseMonthly(
                                        itemKey,
                                        maxCount,
                                      )
                                    : false;
                                final bool canBuyFirst7 = isFirst7
                                    ? store.canPurchaseFirst7(itemKey, maxCount)
                                    : false;
                                final bool canBuyFirst30 = isFirst30
                                    ? store.canPurchaseFirst30(
                                        itemKey,
                                        maxCount,
                                      )
                                    : false;
                                final bool showBuy =
                                    isUnlimited ||
                                    canBuyLimited ||
                                    canBuyDaily ||
                                    canBuyMonthly ||
                                    canBuyFirst7 ||
                                    canBuyFirst30;
                                final String buyText = i18n.getString(
                                  'store.btn.buy',
                                  defaultValue: 'Buy',
                                );
                                final String ownedText = i18n.getString(
                                  'store.btn.owned',
                                  defaultValue: 'Owned',
                                );
                                final String disabledText = i18n.getString(
                                  'store.btn.disabled',
                                  defaultValue: 'Disabled',
                                );

                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    // 主購買按鈕（不經廣告）
                                    if (showBuy)
                                      GestureDetector(
                                        onTap: () async {
                                          if (isDaily) {
                                            await store.purchaseDaily(itemKey);
                                          } else if (isMonthly) {
                                            await store.purchaseMonthly(
                                              itemKey,
                                            );
                                          } else if (isFirst7 || isFirst30) {
                                            await store.purchaseFirstWindow(
                                              itemKey,
                                            );
                                          } else {
                                            await store.purchase(itemKey);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF00FFD1,
                                            ).withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            buyText,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          isLimited ? ownedText : disabledText,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                    // 廣告購買按鈕（ads_pay=true 時顯示）
                                    if (adsPay && showBuy)
                                      GestureDetector(
                                        onTap: () async {
                                          final title = i18n.getString(
                                            'store.ads.title',
                                            defaultValue:
                                                'Watch Ad to Purchase',
                                          );
                                          await RewardedAdService().showAd(
                                            context: context,
                                            onAdWatched: () async {
                                              if (isDaily) {
                                                await store.purchaseDaily(
                                                  itemKey,
                                                );
                                              } else if (isMonthly) {
                                                await store.purchaseMonthly(
                                                  itemKey,
                                                );
                                              } else if (isFirst7 ||
                                                  isFirst30) {
                                                await store.purchaseFirstWindow(
                                                  itemKey,
                                                );
                                              } else {
                                                await store.purchase(itemKey);
                                              }
                                            },
                                            dialogTitle: title,
                                            rewardContent: Text(
                                              name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            showSuccessDialog: true,
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF00FFD1,
                                            ).withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            i18n.getString(
                                              'store.btn.ad_buy',
                                              defaultValue: 'Ad Purchase',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (adsPay)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          i18n.getString(
                                            'store.btn.ad_buy',
                                            defaultValue: 'Ad Purchase',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    // 限制標籤
                                    if (badgeText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          badgeText,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (adsPay)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('🎬', style: TextStyle(fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _badgeText(LocalizationService i18n, String type) {
    switch (type) {
      case 'limited':
        return i18n.getString('store.badge.once');
      case 'unlimited':
        return i18n.getString('store.badge.repeat');
      case 'daily':
        return i18n.getString('store.badge.daily');
      case 'monthly':
        return i18n.getString('store.badge.monthly');
      case 'first7':
        return i18n.getString('store.badge.first7');
      case 'first30':
        return i18n.getString('store.badge.first30');
      default:
        return '';
    }
  }
}

class _StoreCardImage extends StatelessWidget {
  final String imagePath;
  const _StoreCardImage({required this.imagePath});

  static const String _placeholder = 'assets/images/store/placeholder.png';

  @override
  Widget build(BuildContext context) {
    Widget fallbackIcon() {
      return Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white54),
        ),
      );
    }

    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) {
        // 讀取 placeholder.png，若缺少資產則退回 icon
        return Image.asset(
          _placeholder,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (context, _, _) => fallbackIcon(),
        );
      },
    );
  }
}
