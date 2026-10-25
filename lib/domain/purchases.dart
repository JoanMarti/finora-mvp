import 'package:finora/domain/trust.dart';

/// Outcome of a store interaction.
enum PurchaseStatus { purchased, restored, nothingToRestore, cancelled, failed }

class PurchaseResult {
  const PurchaseResult(this.status, {this.since, this.receipt});

  final PurchaseStatus status;

  /// Start of the active subscription, when there is one.
  final DateTime? since;

  /// Store receipt or purchase token, to be verified by the backend
  /// (`POST /v1/purchases/verify`) before Plus is unlocked for good.
  final String? receipt;

  bool get isActive =>
      status == PurchaseStatus.purchased || status == PurchaseStatus.restored;
}

/// A Premium plan as the store sells it, with its localised price.
class StorePrice {
  const StorePrice({
    required this.period,
    required this.formattedPrice,
    this.freeTrialDays,
  });

  final BillingPeriod period;

  /// Price as the store formats it for the user's country, e.g. "CHF 59.00".
  final String formattedPrice;

  /// Length of the introductory free trial, when the store offers one.
  final int? freeTrialDays;
}

/// Buying and restoring Finora Premium. The store build implements this
/// with Google Play Billing (`PlayPurchaseService`).
abstract interface class PurchaseService {
  /// Whether this build takes real payments.
  bool get isStore;

  /// Subscribes to Premium, billed monthly or yearly. [withTrial] starts
  /// with the store's free trial when the user is still eligible.
  Future<PurchaseResult> buyPlus({
    BillingPeriod period = BillingPeriod.yearly,
    bool withTrial = false,
  });
  Future<PurchaseResult> restore();

  /// Store prices by billing period; empty when the store gives none (then
  /// the app shows its reference prices).
  Future<Map<BillingPeriod, StorePrice>> prices();
}

/// Demo: every purchase succeeds immediately and nothing is charged.
class DemoPurchaseService implements PurchaseService {
  const DemoPurchaseService(this._now);

  final DateTime Function() _now;

  @override
  bool get isStore => false;

  @override
  Future<PurchaseResult> buyPlus({
    BillingPeriod period = BillingPeriod.yearly,
    bool withTrial = false,
  }) async =>
      PurchaseResult(PurchaseStatus.purchased, since: _now());

  /// There is no store account behind the demo, so nothing is found.
  @override
  Future<PurchaseResult> restore() async =>
      const PurchaseResult(PurchaseStatus.nothingToRestore);

  @override
  Future<Map<BillingPeriod, StorePrice>> prices() async => const {};
}

/// Permission to show notifications on this device.
abstract interface class NotificationPermissions {
  /// Asks the operating system; `true` when notifications are allowed.
  Future<bool> request();
}

/// Demo: behaves as if the user allowed notifications. A mobile build
/// asks iOS/Android, then registers the push token with the backend.
class DemoNotificationPermissions implements NotificationPermissions {
  const DemoNotificationPermissions();

  @override
  Future<bool> request() async => true;
}
