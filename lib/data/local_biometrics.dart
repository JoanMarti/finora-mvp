import 'package:finora/domain/app_lock.dart';
import 'package:local_auth/local_auth.dart';

/// [BiometricAuth] with the `local_auth` plugin. Any plugin error counts
/// as "not recognised", so the PIN keypad stays available.
class LocalBiometrics implements BiometricAuth {
  LocalBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}
