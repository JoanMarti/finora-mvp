import 'package:finora/app/app.dart';
import 'package:finora/app/bootstrap.dart';
import 'package:finora/data/shared_preferences_session_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: appOverrides(
        sessionStore: SharedPreferencesSessionStore(preferences),
      ),
      child: const FinoraApp(),
    ),
  );
}
