# Finora MVP

Finora is a mobile-first, read-only wealth overview for people in Switzerland. This MVP demonstrates the primary journey with realistic mock data: understand a user's financial setup, simulate institution connections, view unified net worth and allocation, and then explore each account or transaction in its dedicated detail area.

[Live demo](https://joanmarti.github.io/finora-mvp/) · [Source code](https://github.com/JoanMarti/finora-mvp)

> **Demo only:** every balance, transaction, profile and connection state in this repository is fictional. No bank credentials, consent tokens, or personal financial data are collected.

## MVP scope

- Adaptive onboarding: welcome, mock account creation, product selection, banks, optional investments and Pillar 3a branches, and review
- Simulated connection flow with bank hand-off/synchronisation states
- Wealth dashboard with net-worth evolution, goal progress and a personalized ideas carousel
- Accessible account groups with institution marks, product filters and secondary connection actions
- Explainable account analytics: selectable periods, balance evolution, cash flow, spending categories, recurring payments, monitoring and improvement signals
- Recent transactions across institutions
- Profile and connection management
- Basic data-health states: healthy, stale, action required and manual
- Mobile-first Material 3 UI that also runs as Flutter Web
- Riverpod state/dependency management and declarative `go_router` navigation

- Demo data generated from the onboarding answers: the institutions and products you pick are exactly what the overview shows
- Net worth, allocation, history, wealth plan, ideas and alerts derived from account data (nothing hard-coded on screen)
- Session persisted on the device (onboarding choices and preferences only), with a router guard so returning users skip onboarding
- Working transaction search, month grouping and CSV copy; notification centre fed by connection health and upcoming bills
- Available in English, German, French and Italian, following the device language or a choice saved in Profile
- Inter as the app font on every platform

Not included: real authentication, KYC, payments, trading, financial advice, real bLink/OpenWealth calls, analytics, or production security controls.

## Architecture

The project uses a feature/domain structure so financial concepts are shared across screens instead of being owned by a single page.

```text
lib/
├── app/                         # app, theme, router and bootstrap (data-source wiring)
├── application/
│   ├── providers.dart           # Riverpod providers and derived state (overview, alerts)
│   └── session_controller.dart  # persisted user session
├── domain/
│   ├── models.dart              # normalized financial entities (Money in Rappen, DateTime)
│   ├── institution_catalogue.dart # single source of truth for supported institutions
│   ├── user_session.dart        # session model and SessionStore contract
│   ├── financial_repository.dart# banking data-source contract
│   └── market_data_repository.dart # market-content contract
├── data/
│   ├── mock_financial_repository.dart   # demo data built from the session
│   ├── mock_market_data_repository.dart
│   └── shared_preferences_session_store.dart
├── l10n/
│   ├── app_{en,de,fr,it}.arb    # translations (source of truth for UI text)
│   ├── labels.dart              # localized names for domain enums, dates, alerts
│   └── l10n.dart                # context.l10n and the language list
├── features/
│   ├── onboarding/              # profile discovery and branching
│   ├── connections/             # simulated consent/sync journey
│   ├── overview/                # dashboard screen (+ widgets/ for its cards)
│   ├── accounts/                # list, institution and account detail (+ widgets/)
│   ├── activity/                # transaction feed
│   ├── profile/                 # settings and data health
│   └── shell/                   # bottom navigation
└── shared/                      # reusable presentation components
```

The UI depends on `FinancialRepository` through `application/providers.dart` and never imports `data/`. The concrete sources are chosen in one place, `app/bootstrap.dart`. A production integration can add `BlinkFinancialRepository` and/or `OpenWealthFinancialRepository`, normalize provider payloads into the domain models, and change that override without rewriting the features.

Aggregates are never stored: `overviewProvider` derives net worth, allocation and history from the accounts, so the dashboard cannot disagree with the account list.

```text
bLink / OpenWealth / manual sources
                ↓
       provider adapters
                ↓
  normalized FinancialRepository
                ↓
      Riverpod application state
                ↓
          Flutter features
```

Market and product discovery follows the same boundary through `MarketDataRepository`. The current catalogue is intentionally illustrative. A production provider should run behind a backend-for-frontend so credentials, licenses, entitlements and redistribution rules never reach the Flutter client.

### Market-data integration options

- [SIX Web API](https://www.six-group.com/dam/download/financial-information/display-delivery-capabilities/six-web-api/six-web-api-factsheet-en.pdf) for licensed Swiss and global reference/market data.
- [Bloomberg Data License](https://professional.bloomberg.com/products/data/data-license/) or Server API for enterprise customers with the required commercial agreement and entitlements.
- [Swiss National Bank data portal](https://data.snb.ch/en) for official Swiss macroeconomic series such as rates, yields and FX reference data.

The preferred production flow is `provider → backend adapter/cache → normalized MarketDataRepository → Riverpod → UI`. Provider attribution, timestamps and delayed/live status should accompany every market value.

## Translations

UI text lives in `lib/l10n/app_<locale>.arb`; Dart code never contains user-facing strings. `flutter gen-l10n` (run automatically by `flutter run`, `flutter build` and in CI) generates `AppLocalizations` into `lib/l10n/generated/`, which is not committed. Domain enums stay language-free and are named in `l10n/labels.dart`. `test/l10n_test.dart` fails if a language misses a message or changes its placeholders.

To add a language, copy `app_en.arb`, translate it, add it to `finoraLanguages` in `l10n/l10n.dart` and to the mock market themes.

## Run locally

Use the current stable Flutter SDK (the project was validated with Flutter 3.47.4 / Dart 3.13.3).

```bash
flutter pub get
flutter gen-l10n
flutter run
```

For a browser:

```bash
flutter run -d chrome
```

Quality checks:

```bash
flutter analyze
flutter test
flutter build web --release
```

## Product and technical decisions

- **Read-only first:** the MVP reinforces that Finora cannot move money. Any future payment or trade action should hand the user back to their institution.
- **Value before profiling:** onboarding asks only what is required to assemble an overview. Goals, risk tolerance and income belong in later progressive profiling if the product needs them.
- **Institution and account are separate:** UBS can own several accounts without duplicating institution metadata or connection health.
- **Money is exact:** amounts are stored as integer Rappen; dates are `DateTime` and formatted only in the UI.
- **Data health is a domain concern:** freshness and consent state remain separate from balances, enabling consistent warnings across dashboard, institution and profile views.
- **Mock behind an interface:** the journey can be validated before commercial/API onboarding with SIX bLink and OpenWealth is complete.
- **Wealth before accounts:** the first tab explains net worth, evolution, allocation and next actions. Institutions and transactions remain in dedicated detail tabs.
- **Plan before products:** the dashboard connects balances to personal targets before introducing educational investment ideas.
- **Insight before cross-sell:** optional insurance or debt services are shown only after an explainable account signal, remain visually separate from core analytics, and require explicit consent to continue.
- **Monitoring creates repeat value:** recurring-bill changes and low-balance forecasts provide an ongoing reason to return without encouraging unnecessary financial products.
- **Accessible account management:** institution and account rows expose descriptive semantics, visible sync states, 48 px actions and a confirmation step before disconnecting a data source.
- **Accessible palette system:** the supplied white, silver, slate, ink and blue palette is centralized in the app theme. Darker derived text tokens preserve readable contrast, while green, amber and red are reserved for financial and connection states.
- **Education before recommendations:** Swiss investment themes are exploratory and disclose that they are not personalized investment advice.
- **Licensed data stays server-side:** Bloomberg or SIX credentials and entitlements belong in a backend adapter, never in the Flutter bundle.

## Suggested next steps

1. Validate the onboarding, connection comprehension and dashboard hierarchy with 5–8 Swiss multi-bank users.
2. Confirm product coverage, contracts, consent flows and unit economics with SIX bLink/OpenWealth providers.
3. Select and license a market-data provider; prototype SNB macro data separately from commercial product/pricing data.
4. Add encrypted session/token handling in a backend-for-frontend; never ship provider secrets in Flutter.
5. Add real authentication, secure local storage, consent renewal and connection recovery.
6. Add repository contract tests and golden/accessibility tests before broad beta distribution.
7. Introduce analytics focused on completion, connection success, freshness and repeat dashboard use.

## Deployment

`.github/workflows/deploy-pages.yml` builds Flutter Web and deploys it to GitHub Pages after pushes to `main`. The workflow expects Pages to use **GitHub Actions** as its source.

## License

MIT
