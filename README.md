# citycalls-vendor-mobile

CityCalls vendor/employee field app — Flutter/Dart. Fully independent of `citycalls-customer-mobile`; no shared code between them despite both being Flutter. Serves both Employee and Vendor Technician roles from one binary (`docs/manish/09-vendor-app-functional-plan.md` §6). See [citycalls-docs](../docs) for architecture, API contracts, and screen specs.

## Setup

```bash
flutter pub get
flutter run
```

The API base URL is currently hardcoded in `lib/providers/auth_providers.dart` (`apiClientProvider`) to `http://localhost:4000/api/v1` for local development against `citycalls-api`. Move this to environment-specific config before staging/production builds.

## Structure

- `lib/data/` — Dio API client + one repository class per module
- `lib/sync/` — offline-first sync engine (local queue, conflict handling) — **not yet built**, this is the most architecturally involved piece of this app per `docs/manish/09-vendor-app-functional-plan.md` §1-3
- `lib/providers/` — Riverpod providers/notifiers
- `lib/models/` — local Dart models mirroring `citycalls-api`'s contract
- `lib/screens/`, `lib/widgets/` — Rohit's UI, per `docs/rohit/06-vendor-app-screen-list.md`
- `lib/tokens/` — this app's own copy of design tokens/enum-label maps

## Status

Functional skeleton only: login flow wired end-to-end against `citycalls-api`'s real `/auth/login` endpoint. `flutter analyze` and `flutter test` both pass.

**Not yet built** (the bulk of this app's actual complexity): the offline-first local database (SQLite/Drift), the sync queue and conflict-resolution UI, the job list/execution flow screens, and location-ping tracking — see `docs/manish/09-vendor-app-functional-plan.md` for the full spec.
