/// Public pages the stores and the app link to. They are served from the
/// web build (`web/`), so they ship with every deploy; a production domain
/// can be set at build time.
const finoraWebBase = String.fromEnvironment(
  'FINORA_WEB_BASE',
  defaultValue: 'https://joanmarti.github.io/finora-mvp/',
);

final privacyPolicyUrl = Uri.parse('${finoraWebBase}privacy.html');
final deleteAccountUrl = Uri.parse('${finoraWebBase}delete-account.html');
