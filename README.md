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

Not included: real authentication, KYC, payments, trading, financial advice, real bLink/OpenWealth calls, persistent storage, analytics, or production security controls.

## Architecture

The project uses a feature/domain structure so financial concepts are shared across screens instead of being owned by a single page.

```text
lib/
├── app/                         # app shell, theme and router
├── domain/
│   ├── models.dart              # normalized financial entities
│   ├── financial_repository.dart# banking data-source contract
│   └── market_data_repository.dart # market-content contract
├── data/
│   ├── mock_financial_repository.dart
│   └── mock_market_data_repository.dart
├── features/
│   ├── onboarding/              # profile discovery and branching
│   ├── connections/             # simulated consent/sync journey
│   ├── overview/                # aggregate dashboard
│   ├── accounts/                # account/institution views
│   ├── activity/                # transaction feed
│   ├── profile/                 # settings and data health
│   └── shell/                   # bottom navigation
└── shared/                      # reusable presentation components
```

The UI depends on `FinancialRepository`, not on the mock implementation. A production integration can add `BlinkFinancialRepository` and/or `OpenWealthFinancialRepository`, normalize provider payloads into the domain models, and replace the Riverpod provider override without rewriting the features.

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

## Run locally

Use the current stable Flutter SDK (the project was validated with Flutter 3.47.4 / Dart 3.13.3).

```bash
flutter pub get
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
- **Data health is a domain concern:** freshness and consent state remain separate from balances, enabling consistent warnings across dashboard, institution and profile views.
- **Mock behind an interface:** the journey can be validated before commercial/API onboarding with SIX bLink and OpenWealth is complete.
- **Wealth before accounts:** the first tab explains net worth, evolution, allocation and next actions. Institutions and transactions remain in dedicated detail tabs.
- **Plan before products:** the dashboard connects balances to personal targets before introducing educational investment ideas.
- **Insight before cross-sell:** optional insurance or debt services are shown only after an explainable account signal, remain visually separate from core analytics, and require explicit consent to continue.
- **Monitoring creates repeat value:** recurring-bill changes and low-balance forecasts provide an ongoing reason to return without encouraging unnecessary financial products.
- **Accessible account management:** institution and account rows expose descriptive semantics, visible sync states, 48 px actions and a confirmation step before disconnecting a data source.
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
