import 'package:finora/app/router.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/features/lock/lock_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FinoraApp extends ConsumerWidget {
  const FinoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(
      sessionProvider.select((session) => session.languageCode),
    );
    // Keeps reminders and funnel counts in step with a configured backend.
    ref.watch(backendSyncProvider);
    // Store builds confirm the Premium subscription with Google Play.
    ref.watch(billingSyncProvider);
    final hideAmounts = ref.watch(
      sessionProvider.select((session) => session.hideAmounts),
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildFinoraTheme(),
      locale: languageCode == null ? null : Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Date and month names use intl's default locale; keep it aligned
      // with the language the app resolved to.
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).languageCode;
        // Amounts are formatted by plain functions, so switching the mode
        // rebuilds the whole tree; the router keeps the current location.
        AmountPrivacy.hidden = hideAmounts;
        return AppLockGate(
          child: KeyedSubtree(
            key: ValueKey(hideAmounts),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
