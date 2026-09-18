import 'package:finora/app/router.dart';
import 'package:finora/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinoraApp extends ConsumerWidget {
  const FinoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Finora',
      debugShowCheckedModeBanner: false,
      theme: buildFinoraTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
