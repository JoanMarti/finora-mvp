import 'dart:async';

import 'package:finora/domain/purchases.dart';
import 'package:finora/domain/trust.dart';

/// One way to buy Premium: a base plan (monthly or yearly) or its
/// introductory free-trial offer.
class StoreOffer {
  const StoreOffer({
    required this.period,
    required this.formattedPrice,
    this.freeTrialDays,
    this.handle,
  });

  final BillingPeriod period;
  final String formattedPrice;

  /// Days of free trial for an introductory offer; `null` for the base plan.
  final int? freeTrialDays;

  /// Whatever the billing library needs to buy exactly this offer.
  final Object? handle;

  bool get isTrial => freeTrialDays != null;
}

enum StorePurchaseState { pending, purchased, restored, cancelled, error }

/// A purchase update from the store.
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.state,
    this.date,
    this.receipt,
    this.needsAcknowledgement = false,
    this.handle,
  });

  final String productId;
  final StorePurchaseState state;
  final DateTime? date;

  /// Purchase token to verify on the server.
  final String? receipt;

  /// Google cancels purchases that are not acknowledged within three days.
  final bool needsAcknowledgement;
  final Object? handle;
}

/// The few billing calls Finora needs, so the purchase logic can be tested
/// without a phone. `InAppPurchasePort` implements it with the plugin.
abstract interface class BillingPort {
  Future<bool> isAvailable();
  Future<List<StoreOffer>> offers(String productId);
  Future<void> buy(StoreOffer offer);
  Future<void> restore();
  Future<void> acknowledge(StorePurchase purchase);
  Stream<List<StorePurchase>> get updates;
}

/// Server-side check of a purchase token (`POST /v1/purchases/verify`).
typedef PurchaseVerifier = Future<bool> Function(String receipt);

/// Premium through Google Play Billing: one subscription with a monthly
/// and a yearly base plan, each with a 14-day free-trial offer.
class PlayPurchaseService implements PurchaseService {
  PlayPurchaseService(
    this._port, {
    this.productId = 'finora_premium',
    this.verify,
    this.timeout = const Duration(minutes: 5),
    this.restoreWindow = const Duration(seconds: 6),
  });

  final BillingPort _port;
  final String productId;
  final PurchaseVerifier? verify;
  final Duration timeout;

  /// How long to collect restored purchases after asking the store.
  final Duration restoreWindow;

  @override
  bool get isStore => true;

  Future<List<StoreOffer>> _offers() async {
    if (!await _port.isAvailable()) return const [];
    return _port.offers(productId);
  }

  @override
  Future<Map<BillingPeriod, StorePrice>> prices() async {
    final offers = await _offers();
    return {
      for (final period in BillingPeriod.values)
        if (offers.where((offer) => offer.period == period).toList()
            case final forPeriod when forPeriod.isNotEmpty)
          period: StorePrice(
            period: period,
            formattedPrice: forPeriod
                .firstWhere(
                  (offer) => !offer.isTrial,
                  orElse: () => forPeriod.first,
                )
                .formattedPrice,
            freeTrialDays: forPeriod
                .where((offer) => offer.isTrial)
                .firstOrNull
                ?.freeTrialDays,
          ),
    };
  }

  @override
  Future<PurchaseResult> buyPlus({
    BillingPeriod period = BillingPeriod.yearly,
    bool withTrial = false,
  }) async {
    final offers = (await _offers())
        .where((offer) => offer.period == period)
        .toList();
    if (offers.isEmpty) return const PurchaseResult(PurchaseStatus.failed);
    // The trial offer when asked for and still offered to this user (Play
    // only returns offers the user is eligible for), else the base plan.
    final offer = withTrial
        ? offers.firstWhere(
            (offer) => offer.isTrial,
            orElse: () => offers.firstWhere((offer) => !offer.isTrial),
          )
        : offers.firstWhere(
            (offer) => !offer.isTrial,
            orElse: () => offers.first,
          );

    final result = Completer<PurchaseResult>();
    final subscription = _port.updates.listen((updates) async {
      for (final update in updates.where((u) => u.productId == productId)) {
        switch (update.state) {
          case StorePurchaseState.pending:
            continue;
          case StorePurchaseState.purchased || StorePurchaseState.restored:
            final outcome = await _settle(update, PurchaseStatus.purchased);
            if (!result.isCompleted) result.complete(outcome);
          case StorePurchaseState.cancelled:
            if (!result.isCompleted) {
              result.complete(const PurchaseResult(PurchaseStatus.cancelled));
            }
          case StorePurchaseState.error:
            if (!result.isCompleted) {
              result.complete(const PurchaseResult(PurchaseStatus.failed));
            }
        }
      }
    });
    try {
      await _port.buy(offer);
      return await result.future.timeout(
        timeout,
        onTimeout: () => const PurchaseResult(PurchaseStatus.cancelled),
      );
    } on Object {
      return const PurchaseResult(PurchaseStatus.failed);
    } finally {
      await subscription.cancel();
    }
  }

  /// Verifies (when a server is configured) and acknowledges a purchase.
  Future<PurchaseResult> _settle(
    StorePurchase purchase,
    PurchaseStatus success,
  ) async {
    final receipt = purchase.receipt;
    if (verify != null && receipt != null && !await verify!(receipt)) {
      return const PurchaseResult(PurchaseStatus.failed);
    }
    if (purchase.needsAcknowledgement) await _port.acknowledge(purchase);
    return PurchaseResult(success, since: purchase.date, receipt: receipt);
  }

  @override
  Future<PurchaseResult> restore() async {
    if (!await _port.isAvailable()) {
      return const PurchaseResult(PurchaseStatus.failed);
    }
    final found = <StorePurchase>[];
    final subscription = _port.updates.listen((updates) {
      found.addAll(
        updates.where(
          (u) =>
              u.productId == productId &&
              (u.state == StorePurchaseState.restored ||
                  u.state == StorePurchaseState.purchased),
        ),
      );
    });
    try {
      await _port.restore();
      await Future<void>.delayed(restoreWindow);
    } finally {
      await subscription.cancel();
    }
    if (found.isEmpty) {
      return const PurchaseResult(PurchaseStatus.nothingToRestore);
    }
    // The most recent purchase decides.
    found.sort(
      (a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)),
    );
    final outcome = await _settle(found.first, PurchaseStatus.restored);
    return outcome.isActive
        ? outcome
        : const PurchaseResult(PurchaseStatus.nothingToRestore);
  }
}
