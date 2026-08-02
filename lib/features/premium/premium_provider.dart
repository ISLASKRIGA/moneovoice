import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/dependency_injection.dart';

const kPremiumMonthlyId     = 'moneovoice_premium_monthly';
const kPremiumYearlyId      = 'moneovoice_premium_yearly';
const _kPremiumPrefsKey     = 'is_premium';
const int kFreeTransactionLimit = 20;
const int kFreeListLimit        = 1;

// Mantener compatibilidad con código existente
const kPremiumProductId = kPremiumMonthlyId;

class PremiumNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  PremiumNotifier(this._prefs) : super(_prefs.getBool(_kPremiumPrefsKey) ?? false) {
    _init();
  }

  Future<void> _init() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return;

    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchases);
    await InAppPurchase.instance.restorePurchases();
  }

  void _onPurchases(List<PurchaseDetails> list) {
    bool foundActive = false;

    for (final p in list) {
      final isOurs = p.productID == kPremiumMonthlyId || p.productID == kPremiumYearlyId;
      if (!isOurs) continue;

      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        foundActive = true;
        _prefs.setBool(_kPremiumPrefsKey, true);
        state = true;
      }

      if (p.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(p);
      }
    }

    final allOurs = list.every((p) =>
        p.productID == kPremiumMonthlyId || p.productID == kPremiumYearlyId);
    if (!foundActive && list.isNotEmpty && allOurs) {
      _prefs.setBool(_kPremiumPrefsKey, false);
      state = false;
    }
  }

  /// Compra mensual o anual según [productId].
  Future<String?> purchase(String productId) async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return 'La tienda no está disponible en este dispositivo.';

    final resp = await InAppPurchase.instance.queryProductDetails({productId});
    if (resp.productDetails.isEmpty) {
      return 'No se encontró la suscripción. Intenta más tarde.';
    }

    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: resp.productDetails.first),
    );
    return null;
  }

  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PremiumNotifier(prefs);
});
