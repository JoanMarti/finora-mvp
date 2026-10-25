import 'package:finora/data/billing/play_purchase_service.dart';
import 'package:finora/domain/trust.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// [BillingPort] over the official `in_app_purchase` plugin (Google Play).
///
/// Play Console setup this expects (docs/release-android.md):
/// subscription `finora_premium` with base plans `monthly` and `yearly`,
/// each with a free-trial offer (`trial-14d`).
class InAppPurchasePort implements BillingPort {
  InAppPurchasePort([InAppPurchase? plugin])
    : _plugin = plugin ?? InAppPurchase.instance;

  final InAppPurchase _plugin;

  static const _basePlans = {
    'monthly': BillingPeriod.monthly,
    'yearly': BillingPeriod.yearly,
  };

  @override
  Future<bool> isAvailable() => _plugin.isAvailable();

  @override
  Future<List<StoreOffer>> offers(String productId) async {
    final response = await _plugin.queryProductDetails({productId});
    final offers = <StoreOffer>[];
    for (final details in response.productDetails) {
      if (details is! GooglePlayProductDetails) continue;
      final index = details.subscriptionIndex;
      final all = details.productDetails.subscriptionOfferDetails;
      if (index == null || all == null || index >= all.length) continue;
      final offer = all[index];
      final period = _basePlans[offer.basePlanId];
      if (period == null) continue;
      offers.add(
        StoreOffer(
          period: period,
          // The recurring phase is the last one; a trial phase costs 0.
          formattedPrice: offer.pricingPhases.isEmpty
              ? details.price
              : offer.pricingPhases.last.formattedPrice,
          freeTrialDays: offer.offerId == null
              ? null
              : _freeTrialDays(offer.pricingPhases),
          handle: details,
        ),
      );
    }
    return offers;
  }

  /// Days of the free phase of an offer, from its ISO 8601 period
  /// ("P14D", "P2W", "P1M").
  static int? _freeTrialDays(List<PricingPhaseWrapper> phases) {
    final free = phases.where((phase) => phase.priceAmountMicros == 0);
    if (free.isEmpty) return null;
    final match = RegExp(r'^P(\d+)([DWM])$').firstMatch(free.first.billingPeriod);
    if (match == null) return null;
    final count = int.parse(match.group(1)!);
    return switch (match.group(2)) {
      'W' => count * 7,
      'M' => count * 30,
      _ => count,
    };
  }

  @override
  Future<void> buy(StoreOffer offer) async {
    final details = offer.handle;
    if (details is! GooglePlayProductDetails) {
      throw StateError('Not a Google Play offer');
    }
    // A GooglePlayProductDetails carries the offer token of its base plan
    // or offer, so this buys exactly the chosen one.
    await _plugin.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restore() => _plugin.restorePurchases();

  @override
  Future<void> acknowledge(StorePurchase purchase) async {
    final details = purchase.handle;
    if (details is PurchaseDetails) await _plugin.completePurchase(details);
  }

  @override
  Stream<List<StorePurchase>> get updates => _plugin.purchaseStream.map(
    (list) => [
      for (final details in list)
        StorePurchase(
          productId: details.productID,
          state: switch (details.status) {
            PurchaseStatus.pending => StorePurchaseState.pending,
            PurchaseStatus.purchased => StorePurchaseState.purchased,
            PurchaseStatus.restored => StorePurchaseState.restored,
            PurchaseStatus.canceled => StorePurchaseState.cancelled,
            PurchaseStatus.error => StorePurchaseState.error,
          },
          date: details.transactionDate == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  int.tryParse(details.transactionDate!) ?? 0,
                ),
          receipt: details.verificationData.serverVerificationData,
          needsAcknowledgement: details.pendingCompletePurchase,
          handle: details,
        ),
    ],
  );
}
