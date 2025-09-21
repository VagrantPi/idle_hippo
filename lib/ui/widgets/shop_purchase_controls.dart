import 'dart:async';

import 'package:flutter/material.dart';
import 'package:idle_hippo/services/integrated_store_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/models/purchase_models.dart';

enum UiPurchaseState {
  idle,
  loadingPrice,
  ready,
  purchasing,
  verifying,
  owned,
  soldOut,
  limitedReached,
  disabled,
}

class ShopPurchaseControls extends StatefulWidget {
  final String itemKey; // storeId
  final String limitType; // limited/daily/monthly/first7/first30/unlimited
  final bool adsPay;
  final dynamic orchestrator; // 保留相容參數，實際不再使用

  const ShopPurchaseControls({
    super.key,
    required this.itemKey,
    required this.limitType,
    this.adsPay = false,
    this.orchestrator,
  });

  @override
  State<ShopPurchaseControls> createState() => _ShopPurchaseControlsState();
}

class _ShopPurchaseControlsState extends State<ShopPurchaseControls> {
  final _i18n = LocalizationService();
  UiPurchaseState _state = UiPurchaseState.loadingPrice;
  String? _priceText;
  String? _errorKey;

  StreamSubscription? _sub; // 不再使用 orchestrator 的狀態流

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 載入價格：直接透過 IntegratedStoreService.queryProducts
    setState(() {
      _state = UiPurchaseState.loadingPrice;
      _errorKey = null;
    });
    try {
      final List<ProductInfo> list =
          await IntegratedStoreService().queryProducts([widget.itemKey]);
      if (list.isNotEmpty && mounted) {
        final p = list.first;
        _priceText = _formatPrice(p.price, p.currency);
      }
    } catch (_) {}

    final availability =
        await IntegratedStoreService().getAvailability(widget.itemKey);
    if (!mounted) return;
    if (availability.canBuy) {
      setState(() {
        _state = UiPurchaseState.ready;
        _errorKey = null;
      });
    } else {
      setState(() {
        _state = _mapUnavailabilityToState(widget.limitType);
        _errorKey = availability.reasonKey ?? _mapErrorCode('unknown');
      });
    }
  }

  String _formatPrice(double? price, String? currency) {
    if (price == null) return '';
    return currency == null ? price.toStringAsFixed(2) : '${price.toStringAsFixed(2)} $currency';
  }

  UiPurchaseState _successLandingState(String limitType) {
    switch (limitType) {
      case 'limited':
      case 'first7':
      case 'first30':
        return UiPurchaseState.owned;
      case 'daily':
      case 'monthly':
        // 規格調整：購買完成後顯示「已擁有」作為正向回饋
        return UiPurchaseState.owned;
      case 'unlimited':
      default:
        return UiPurchaseState.ready;
    }
  }

  UiPurchaseState _mapUnavailabilityToState(String limitType) {
    switch (limitType) {
      case 'limited':
      case 'first7':
      case 'first30':
        return UiPurchaseState.owned;
      case 'daily':
      case 'monthly':
        return UiPurchaseState.limitedReached;
      default:
        return UiPurchaseState.disabled;
    }
  }

  String? _mapErrorCode(String code) {
    const mapping = {
      'verify_failed': 'store.errors.verify_failed',
      'verify_exception': 'store.errors.verify_exception',
      'canceled': 'store.errors.canceled',
      'purchase_error': 'store.errors.purchase_error',
      'not_initialized': 'store.errors.not_initialized',
      'product_not_found': 'store.unavailable.product_not_found',
      'unknown': 'store.errors.unknown',
    };
    return mapping[code];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabledText = _i18n.getString('store.btn.disabled', defaultValue: 'Locked');
    final buyText = _i18n.getString('store.btn.buy', defaultValue: 'Purchase');
    final stateLabel = _state.name;

    final isDailyPack = widget.itemKey == 'store.pack_daily';
    final buttons = <Widget>[];
    switch (_state) {
      case UiPurchaseState.ready:
        final label = '$buyText${_priceText != null && _priceText!.isNotEmpty ? ' ($_priceText)' : ''}';
        if (isDailyPack) {
          buttons.add(_buildActiveButton(label, _onPurchaseIap));
          buttons.add(_buildActiveButton(
            _i18n.getString('store.btn.ad_buy', defaultValue: 'Watch Ad'),
            _onPurchaseAd,
            bgColor: Colors.orange,
          ));
        } else if (widget.adsPay) {
          buttons.add(_buildActiveButton(
            _i18n.getString('store.btn.ad_buy', defaultValue: 'Watch Ad'),
            _onPurchaseAd,
            bgColor: Colors.orange,
          ));
        } else {
          buttons.add(_buildActiveButton(label, _onPurchaseIap));
        }
        break;
      case UiPurchaseState.purchasing:
        buttons.add(_buildDisabledButton(
          _i18n.getString('store.ui.purchasing', defaultValue: 'Purchasing...'),
        ));
        break;
      case UiPurchaseState.verifying:
        buttons.add(_buildDisabledButton(
          _i18n.getString('store.ui.verifying', defaultValue: 'Verifying...'),
        ));
        break;
      case UiPurchaseState.owned:
        buttons.add(_buildDisabledButton(_i18n.getString('store.btn.owned', defaultValue: 'Owned')));
        break;
      case UiPurchaseState.limitedReached:
        buttons.add(_buildDisabledButton(_i18n.getString('store.unavailable.limited_cap', defaultValue: disabledText)));
        break;
      case UiPurchaseState.disabled:
      case UiPurchaseState.loadingPrice:
      case UiPurchaseState.idle:
      case UiPurchaseState.soldOut:
        final text = _errorKey != null ? _i18n.getString(_errorKey!, defaultValue: disabledText) : disabledText;
        buttons.add(_buildDisabledButton(text));
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expose state for tests
        Text(stateLabel, key: Key('${widget.itemKey}__state'), style: const TextStyle(fontSize: 0)),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...buttons,
          ],
        ),
      ],
    );
  }

  Widget _buildActiveButton(String text, VoidCallback onTap, {Color bgColor = const Color(0xFF00FFD1)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _onPurchaseIap() async {
    setState(() {
      _errorKey = null;
      _state = UiPurchaseState.purchasing;
    });
    try {
      await IntegratedStoreService().buyProductViaIap(widget.itemKey);
      // 模擬驗證階段（UI 視覺需求），不阻塞實際流程
      if (!mounted) return;
      setState(() => _state = UiPurchaseState.verifying);
      // 可用極短暫延遲呈現 UI 狀態
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _i18n.getString('store.purchase_success', defaultValue: 'Purchase successful!'),
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _state = _successLandingState(widget.limitType);
        _errorKey = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is PurchaseFlowException) {
        _errorKey = _mapErrorCode(e.code) ?? 'store.purchase_failed';
      } else {
        _errorKey ??= 'store.errors.unknown';
      }
      final msgKey = _errorKey ?? 'store.purchase_failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_i18n.getString(msgKey, defaultValue: 'Purchase failed!')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        // 依規格：失敗回到 ready（可重試）
        _state = UiPurchaseState.ready;
      });
    }
  }

  Future<void> _onPurchaseAd() async {
    setState(() {
      _errorKey = null;
      _state = UiPurchaseState.purchasing;
    });
    try {
      await IntegratedStoreService().buyProductViaAd(widget.itemKey);
      if (!mounted) return;
      setState(() => _state = UiPurchaseState.verifying);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _i18n.getString('store.purchase_success', defaultValue: 'Purchase successful!'),
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _state = _successLandingState(widget.limitType);
        _errorKey = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is PurchaseFlowException) {
        _errorKey = _mapErrorCode(e.code) ?? 'store.purchase_failed';
      } else {
        _errorKey ??= 'store.errors.unknown';
      }
      final msgKey = _errorKey ?? 'store.purchase_failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_i18n.getString(msgKey, defaultValue: 'Purchase failed!')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _state = UiPurchaseState.ready;
      });
    }
  }
}
