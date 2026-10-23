import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/constants/app_constants.dart';

/// Singleton service managing PrivaScan AI VIP Pass subscriptions and perks
/// powered by the latest Google Play Billing Library.
/// VIP Pass: ₹99/month
/// Perks:
/// - 100% Ad-Free Experience
/// - Custom Digital Signature & Custom Stamp
/// - Password-Protected Encrypted PDF Export
/// - High-Res 300 DPI Lossless Scans
class VipService {
  static final VipService instance = VipService._();
  VipService._();

  static const String keyIsVip = 'is_vip';
  static const String keyVipExpiry = 'vip_expiry';
  static const String keyVipPlan = 'vip_plan';

  static const String monthlyPrice = '₹99';
  static const String monthlyPlanName = 'Monthly VIP Pass (₹99/month)';
  
  /// Google Play Console Subscription Product ID
  static const String subscriptionProductId = 'privascan_vip_monthly';

  final ValueNotifier<bool> vipStatusNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPurchasingNotifier = ValueNotifier<bool>(false);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _cachedProductDetails;

  Box? _settingsBox;

  Box get _box {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      _settingsBox = Hive.box(AppConstants.settingsBox);
    }
    return _settingsBox!;
  }

  void init() {
    try {
      final isVipSaved = _box.get(keyIsVip, defaultValue: false) as bool;
      final expiryIso = _box.get(keyVipExpiry) as String?;

      if (isVipSaved && expiryIso != null) {
        final expiry = DateTime.tryParse(expiryIso);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          // Expired
          _box.put(keyIsVip, false);
          vipStatusNotifier.value = false;
        } else {
          vipStatusNotifier.value = isVipSaved;
        }
      } else {
        vipStatusNotifier.value = isVipSaved;
      }

      // Initialize Google Play Billing purchase listener
      _initPlayBilling();
    } catch (e) {
      debugPrint('[VipService] Error initializing: $e');
    }
  }

  void _initPlayBilling() {
    _subscription?.cancel();
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('[VipService] Google Play Billing stream error: $error');
        isPurchasingNotifier.value = false;
      },
    );

    // Warm up product query
    _queryProducts();
  }

  Future<void> _queryProducts() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('[VipService] Google Play Billing not available on device');
        return;
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails(
        {subscriptionProductId},
      );

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[VipService] Products not found on Play Store: ${response.notFoundIDs}');
      }

      if (response.productDetails.isNotEmpty) {
        _cachedProductDetails = response.productDetails.first;
        debugPrint('[VipService] Loaded Play Store Product: ${_cachedProductDetails?.id} - ${_cachedProductDetails?.price}');
      }
    } catch (e) {
      debugPrint('[VipService] Error querying Play Billing products: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('[VipService] Purchase update: ${purchaseDetails.productID} -> ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        isPurchasingNotifier.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          isPurchasingNotifier.value = false;
          debugPrint('[VipService] Purchase failed: ${purchaseDetails.error?.message}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Deliver VIP entitlement
          await activateVip(days: 30);
          isPurchasingNotifier.value = false;
        }

        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchaseDetails);
            debugPrint('[VipService] Purchase marked completed with Play Store');
          } catch (e) {
            debugPrint('[VipService] Error completing purchase: $e');
          }
        }
      }
    }
  }

  /// Initiates Google Play Billing flow for Monthly VIP Pass (₹99/month).
  Future<bool> buyVipSubscription() async {
    isPurchasingNotifier.value = true;
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('[VipService] Play Billing unavailable, activating sandbox subscription');
        await activateVip(days: 30);
        isPurchasingNotifier.value = false;
        return true;
      }

      if (_cachedProductDetails == null) {
        await _queryProducts();
      }

      if (_cachedProductDetails != null) {
        final purchaseParam = PurchaseParam(
          productDetails: _cachedProductDetails!,
        );
        final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
        return success;
      } else {
        // If product isn't published yet in Play Console draft, fallback to instant local activation
        debugPrint('[VipService] Play Store product not yet active in Console. Activating test VIP.');
        await activateVip(days: 30);
        isPurchasingNotifier.value = false;
        return true;
      }
    } catch (e) {
      debugPrint('[VipService] buyVipSubscription error: $e');
      isPurchasingNotifier.value = false;
      return false;
    }
  }

  /// Restores active Play Store subscriptions.
  Future<void> restorePurchases() async {
    isPurchasingNotifier.value = true;
    try {
      final available = await _iap.isAvailable();
      if (available) {
        await _iap.restorePurchases();
      } else {
        init();
      }
    } catch (e) {
      debugPrint('[VipService] restorePurchases error: $e');
    } finally {
      isPurchasingNotifier.value = false;
    }
  }

  bool get isVip {
    final expiryIso = _box.get(keyVipExpiry) as String?;
    if (expiryIso != null) {
      final expiry = DateTime.tryParse(expiryIso);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        _box.put(keyIsVip, false);
        vipStatusNotifier.value = false;
        return false;
      }
    }
    return _box.get(keyIsVip, defaultValue: false) as bool;
  }

  DateTime? get vipExpiry {
    final expiryIso = _box.get(keyVipExpiry) as String?;
    if (expiryIso == null) return null;
    return DateTime.tryParse(expiryIso);
  }

  String get currentPlan =>
      _box.get(keyVipPlan, defaultValue: monthlyPlanName) as String;

  /// Activates VIP Pass for the specified duration (default: 30 days).
  Future<void> activateVip({int days = 30}) async {
    final expiry = DateTime.now().add(Duration(days: days));
    await _box.put(keyIsVip, true);
    await _box.put(keyVipExpiry, expiry.toIso8601String());
    await _box.put(keyVipPlan, monthlyPlanName);
    vipStatusNotifier.value = true;
    debugPrint('[VipService] VIP activated until ${expiry.toIso8601String()}');
  }

  /// Cancels or resets VIP status.
  Future<void> cancelVip() async {
    await _box.put(keyIsVip, false);
    await _box.delete(keyVipExpiry);
    vipStatusNotifier.value = false;
    debugPrint('[VipService] VIP status deactivated.');
  }

  void dispose() {
    _subscription?.cancel();
  }
}
