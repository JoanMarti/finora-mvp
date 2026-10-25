# Finora reference backend

A small Dart server that implements the v1 API in [`../docs/api.md`](../docs/api.md). It serves the app's demo profile from `fixtures/demo.json`, so the app can be tested end to end against a real HTTP backend:

```sh
cd server
dart pub get
dart run bin/server.dart          # http://localhost:8080/
# in another terminal, from the repository root:
flutter run --dart-define=FINORA_API_URL=http://localhost:8080/
```

| Variable | Default | What it does |
| --- | --- | --- |
| `PORT` | `8080` | Port to listen on. |
| `FINORA_API_TOKEN` | not set | If set, every request must send `Authorization: Bearer <token>`. |

## What it is (and is not)

- **Read endpoints** serve the fixture. `?months=` cuts the balance history (1–24).
- **Write endpoints** keep the data in memory and reject payloads that carry more than the contract allows: no e-mail in the funnel, no names in reminders. This enforces the privacy rules on the server side too.
- **Purchase verification** always answers `active: false`, because the reference server has no store credentials.
- It is **not** the production backend. Production adds OIDC sign-in, bLink and OpenWealth connections, a database, APNs/FCM delivery and store receipt verification.

## Fixture

`fixtures/demo.json` is generated from the app's demo data, so the app and the server cannot drift apart. On pull requests CI regenerates it and commits it when it changes, and `test/contract_test.dart` fails if a committed fixture no longer matches. To regenerate it locally, run from the repository root:

```sh
UPDATE_FIXTURES=1 flutter test test/contract_test.dart
```
