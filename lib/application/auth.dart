import 'package:finora/data/demo_auth_service.dart';
import 'package:finora/domain/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where demo accounts are kept. `main.dart` persists them on the device.
final accountStoreProvider = Provider<AccountStore>(
  (ref) => InMemoryAccountStore(),
);

/// Registration and sign-in. The demo keeps accounts on the device; a
/// backend build overrides this with `HttpAuthService`.
final authServiceProvider = Provider<AuthService>(
  (ref) => DemoAuthService(ref.watch(accountStoreProvider)),
);
