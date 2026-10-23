import 'package:finora/domain/user_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the demo session on the device. It holds no credentials or
/// financial data: only onboarding choices and preferences.
class SharedPreferencesSessionStore implements SessionStore {
  SharedPreferencesSessionStore(this._preferences);

  static const _key = 'finora.session';
  final SharedPreferences _preferences;

  @override
  UserSession? load() => UserSession.decode(_preferences.getString(_key));

  @override
  Future<void> save(UserSession session) =>
      _preferences.setString(_key, session.encode());

  @override
  Future<void> clear() => _preferences.remove(_key);
}
