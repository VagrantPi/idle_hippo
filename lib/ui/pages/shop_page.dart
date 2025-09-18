import 'package:flutter/material.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/integrated_store_service.dart';
import 'package:idle_hippo/models/purchase_models.dart';

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
    // Initialize integrated store service
    IntegratedStoreService().initialize().then((_) {
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
                              animation: IntegratedStoreService(),
                              builder: (context, _) {
                                return FutureBuilder<PurchaseAvailability>(
                                  future: IntegratedStoreService()
                                      .getAvailability(itemKey),
                                  builder: (context, snapshot) {
                                    final availability =
                                        snapshot.data ??
                                        const PurchaseAvailability(false);
                                    final bool showBuy = availability.canBuy;
                                    final bool isDailyPack =
                                        itemKey == 'store.pack_daily';
                                    final String buyText = i18n.getString(
                                      'store.btn.buy',
                                      defaultValue: 'Buy',
                                    );
                                    final String disabledText = i18n.getString(
                                      'store.btn.disabled',
                                      defaultValue: 'Disabled',
                                    );

                                    // 特例：每日禮包同時顯示 IAP 與看廣告兩個按鈕
                                    if (isDailyPack && showBuy) {
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          // IAP 購買按鈕
                                          GestureDetector(
                                            onTap: () async {
                                              try {
                                                await IntegratedStoreService()
                                                    .buyProductViaIap(itemKey);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.purchase_success',
                                                          defaultValue:
                                                              'Purchase successful!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.purchase_failed',
                                                          defaultValue:
                                                              'Purchase failed!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF00FFD1,
                                                ).withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                          ),

                                          // 看廣告購買按鈕
                                          GestureDetector(
                                            onTap: () async {
                                              try {
                                                await IntegratedStoreService()
                                                    .buyProductViaAd(itemKey);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.ad_purchase_success',
                                                          defaultValue:
                                                              'Ad reward received!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.ad_purchase_failed',
                                                          defaultValue:
                                                              'Ad reward failed!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(
                                                  alpha: 0.9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                i18n.getString(
                                                  'store.btn.ad_buy',
                                                  defaultValue: 'Watch Ad',
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    // 其他商品：維持原有邏輯
                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        // 主購買按鈕（IAP）
                                        if (showBuy && !adsPay)
                                          GestureDetector(
                                            onTap: () async {
                                              try {
                                                await IntegratedStoreService()
                                                    .buyProduct(itemKey);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.purchase_success',
                                                          defaultValue:
                                                              'Purchase successful!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.purchase_failed',
                                                          defaultValue:
                                                              'Purchase failed!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF00FFD1,
                                                ).withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                        else if (!showBuy)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              availability.reasonKey != null
                                                  ? i18n.getString(
                                                      availability.reasonKey!,
                                                      defaultValue:
                                                          disabledText,
                                                    )
                                                  : disabledText,
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
                                              try {
                                                await IntegratedStoreService()
                                                    .buyProduct(itemKey);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.ad_purchase_success',
                                                          defaultValue:
                                                              'Ad reward received!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        i18n.getString(
                                                          'store.ad_purchase_failed',
                                                          defaultValue:
                                                              'Ad reward failed!',
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(
                                                  alpha: 0.9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                        // 限制標籤與剩餘次數（first7/first30 額外顯示倒數，使用 i18n 單位）
                                        if (badgeText.isNotEmpty)
                                          FutureBuilder<Map<String, int>?>(
                                            future:
                                                (limitType == 'first7' ||
                                                    limitType == 'first30')
                                                ? IntegratedStoreService()
                                                      .getFirstPeriodRemaining(
                                                        itemKey,
                                                      )
                                                : Future.value(null),
                                            builder: (context, cdSnap) {
                                              final baseText =
                                                  availability.remaining > 0
                                                  ? '$badgeText (${availability.remaining})'
                                                  : badgeText;
                                              String text = baseText;
                                              if (cdSnap.connectionState ==
                                                      ConnectionState.done &&
                                                  cdSnap.data != null) {
                                                final d =
                                                    cdSnap.data!['days'] ?? 0;
                                                final h =
                                                    cdSnap.data!['hours'] ?? 0;
                                                final m =
                                                    cdSnap.data!['minutes'] ??
                                                    0;
                                                final dayUnit = i18n.getString(
                                                  'store.time.day',
                                                  defaultValue: '天',
                                                );
                                                final hourUnit = i18n.getString(
                                                  'store.time.hour',
                                                  defaultValue: '小時',
                                                );
                                                final minuteUnit = i18n
                                                    .getString(
                                                      'store.time.minute',
                                                      defaultValue: '分',
                                                    );
                                                String timeStr;
                                                if (d > 0) {
                                                  timeStr =
                                                      '$d$dayUnit$h$hourUnit';
                                                } else {
                                                  timeStr =
                                                      '$h$hourUnit$m$minuteUnit';
                                                }
                                                final cdTpl = i18n.getString(
                                                  'store.badge.countdown',
                                                  defaultValue: '倒數：{time}',
                                                );
                                                final cdText = cdTpl.replaceAll(
                                                  '{time}',
                                                  timeStr,
                                                );
                                                text = '$baseText · $cdText';
                                              }
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  text,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    );
                                  },
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
