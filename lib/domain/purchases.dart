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

/// Buying and restoring Finora Plus. A store build implements this with
/// the `in_app_purchase` plugin (App Store and Google Play subscriptions).
abstract interface class PurchaseService {
  /// Whether this build takes real payments.
  bool get isStore;

  Future<PurchaseResult> buyPlus();
  Future<PurchaseResult> restore();
}

/// Demo: every purchase succeeds immediately and nothing is charged.
class DemoPurchaseService implements PurchaseService {
  const DemoPurchaseService(this._now);

  final DateTime Function() _now;

  @override
  bool get isStore => false;

  @override
  Future<PurchaseResult> buyPlus() async =>
      PurchaseResult(PurchaseStatus.purchased, since: _now());

  /// There is no store account behind the demo, so nothing is found.
  @override
  Future<PurchaseResult> restore() async =>
      const PurchaseResult(PurchaseStatus.nothingToRestore);
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
