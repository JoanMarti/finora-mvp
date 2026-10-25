# Finora backend API (v1)

The app talks to a **backend-for-frontend (BFF)**. The BFF:
- connects to banks through SIX **bLink** and to portfolios through **OpenWealth**;
- stores the user's consents to those providers;
- returns read-only data in the shapes below.

The app never sees bank credentials and never initiates payments.

Build with a backend:

```sh
flutter run --dart-define=FINORA_API_URL=https://api.example.ch/
```

Without `FINORA_API_URL` the app runs the demo with generated data (`lib/app/bootstrap.dart`).

## Conventions

| Topic | Rule |
| --- | --- |
| Transport | HTTPS and JSON only. Requests send `Accept: application/json`. |
| Auth | `Authorization: Bearer <access token>`, from an OIDC sign-in that is still to be built. `401` means the user must sign in again. |
| Money | `{"cents": 1248040, "currency": "CHF"}`, in integer minor units. Liabilities are negative. |
| Dates | ISO 8601. Day-only values use `YYYY-MM-DD`. |
| Enums | Sent by their Dart name, for example `currentAccount` or `healthInsurance`. Unknown values are rejected, so a new value needs an app release first. |
| Errors | Any non-2xx status becomes `ApiException`, and the screen shows its "unavailable" state. |

## Read endpoints

| Method and path | Returns |
| --- | --- |
| `GET /v1/institutions` | `[{id, name, shortName?, color?, connectionMethod, productTypes[]}]` |
| `GET /v1/connections` | `[{institutionId, status, lastSyncedAt}]` |
| `GET /v1/accounts` | `[{id, institutionId, name, type, balance, maskedIdentifier?, monthlyChange?}]` |
| `GET /v1/accounts/{id}/analytics` | `{monthlyIncome, monthlySpending, balanceHistory[{month, balance}], cashFlowHistory[{month, income, spending}], recurringPayments[{merchant, category, amount, cadence, nextDueAt}], spendingCategories[{category, amount, color?}]}` |
| `GET /v1/transactions?accountId=` | `[{id, accountId, merchant, category, bookedAt, amount}]`, newest first. Without `accountId` it returns all accounts. |
| `GET /v1/pillar3a/contributions?year=` | `{amount}` |
| `GET /v1/tax/{year}` | `{year, asOf, isComplete, pillar3aContributions, accounts[{accountId, closingBalance, income?, interestPaid?}]}` |
| `POST /v1/refresh` | `204`: asks every provider for fresh data. |

## Write endpoints (aggregated data only)

These are keyed by an anonymous `installationId`, 16 random bytes created on the device. They carry no names, e-mail addresses or per-person amounts. Both are idempotent `PUT`s of the full current state, so the app simply sends them again after a failure.

| Method and path | Body |
| --- | --- |
| `PUT /v1/installations/{id}/funnel` | `{counts: {<offerKind>: {viewed, partnerClicked, dismissed}}, pursuedSavingLow, pursuedSavingHigh}`. Amounts are cents; the empty state is sent after the user withdraws consent, so the backend deletes its copy. |
| `PUT /v1/installations/{id}/reminders` | `{language, reminders: [{id, kind, date}]}` for push notifications. Goal and asset names are replaced by a hash in `id`; bills are not sent. |

## Purchases and devices

| Method and path | Body and response |
| --- | --- |
| `POST /v1/purchases/verify` | `{platform: "ios" \| "android", receipt}` returns `{active, since, expiresAt}`. The app unlocks Plus from the store result right away; the backend's answer is authoritative and is checked again on start-up. |
| `PUT /v1/installations/{id}/device` | `{platform, pushToken}`, sent after the user allows notifications. Calling it again replaces the token. |

Reminders are only sent when the user turned them on in the calendar. Kinds they switched off are left out, and turning reminders off sends an empty list.

## Still to build on the backend side

- OIDC sign-in, and the bLink and OpenWealth consent redirect for connecting an institution. In the app this is still the demo connection flow.
- Push delivery (APNs/FCM) from the reminders list, with the device token registered after sign-in.
- Partner sharing for the household view: today the partner's figures are entered on the device.
