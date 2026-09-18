# Finora MVP

Finora is a mobile-first, read-only financial overview for people in Switzerland. This MVP demonstrates the primary journey with realistic mock data: understand a user's financial setup, simulate institution connections, and show accounts, investments, Pillar 3a, data health, and recent transactions in one place.

> **Demo only:** every balance, transaction, profile and connection state in this repository is fictional. No bank credentials, consent tokens, or personal financial data are collected.

## MVP scope

- Adaptive onboarding: welcome, mock account creation, product selection, banks, optional investments and Pillar 3a branches, and review
- Simulated connection flow with bank hand-off/synchronisation states
- Aggregated dashboard with cash, investments, retirement, institutions and recent activity
- Accounts list, institution details and account details
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
│   └── financial_repository.dart# data-source contract
├── data/
│   └── mock_financial_repository.dart
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
- **No charts in V0.1:** hierarchy and comprehension are tested before adding visual density.

## Suggested next steps

1. Validate the onboarding, connection comprehension and dashboard hierarchy with 5–8 Swiss multi-bank users.
2. Confirm product coverage, contracts, consent flows and unit economics with SIX bLink/OpenWealth providers.
3. Add encrypted session/token handling in a backend-for-frontend; never ship provider secrets in Flutter.
4. Add real authentication, secure local storage, consent renewal and connection recovery.
5. Add repository contract tests and golden/accessibility tests before broad beta distribution.
6. Introduce analytics focused on completion, connection success, freshness and repeat dashboard use.

## Deployment

`.github/workflows/deploy-pages.yml` builds Flutter Web and deploys it to GitHub Pages after pushes to `main`. The workflow expects Pages to use **GitHub Actions** as its source.

## License

MIT
