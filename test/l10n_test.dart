import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the four language files in step: every message exists everywhere
/// and uses the same placeholders.
void main() {
  Map<String, Object?> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, Object?>;

  Set<String> messageKeys(Map<String, Object?> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  Set<String> placeholders(String message) => RegExp(r'(?<!\w)\{(\w+)[},]')
      .allMatches(message)
      .map((match) => match.group(1)!)
      .toSet();

  final english = load('en');

  for (final locale in ['de', 'fr', 'it']) {
    test('$locale has every English message with the same placeholders', () {
      final translated = load(locale);
      expect(messageKeys(translated), messageKeys(english));
      for (final key in messageKeys(english)) {
        expect(
          placeholders(translated[key]! as String),
          placeholders(english[key]! as String),
          reason: '$locale/$key',
        );
      }
    });
  }
}
