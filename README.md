# Family Finance

An Android-first, offline-first family finance app built with Flutter. It
tracks expenses, income, monthly budgets, and EMIs locally, with optional
family synchronization through a Google Sheet owned by the household.

## MVP features

- Calm Material 3 dashboard and quick entry flows
- Expense, income, category budget, and EMI tracking
- Monthly cash-flow and category analytics
- Encrypted SQLCipher database and encrypted local backups
- English and Telugu UI, dark theme, and large-text mode
- EMI notifications
- Google Sign-In, Sheets synchronization, and Drive invitations

## Architecture

The presentation layer uses Riverpod. Domain models contain finance rules and
integer minor-unit money values. Repositories and services own SQLite,
notifications, backup encryption, and Google APIs. Local writes complete first
and are queued for sync; remote conflicts use revision, UTC update time, and
device ID as deterministic tie-breakers.

## Setup

1. Install the current stable Flutter SDK and Android Studio.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test`.
4. Start an emulator or connect an Android device, then run `flutter run`.

### Google sync

Create a Google Cloud project, enable Google Sheets API and Google Drive API,
configure the OAuth consent screen, then create:

- an Android OAuth client for package `com.madhav.family_finance_app`, with the
  signing certificate SHA-1 and SHA-256 fingerprints; and
- a Web OAuth client used as Android's server client ID.

The registered Web client ID is bundled as the default, so the configured app
can be started with `flutter run`. A different deployment can override it with:

```shell
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id
```

An OAuth client ID identifies the app and is not a client secret. Never pass or
commit a client secret. Downloaded credentials, signing keys,
`google-services.json`, local databases, and backups are ignored.

The owner creates the household spreadsheet on first sync and can invite
Google accounts from Settings. In-app roles are a convenience boundary only:
any account with direct editor access can modify the Sheet outside the app.

## Security notes

The database key and backup key are generated independently and kept in Android
secure storage. Financial records and access tokens must never be logged.
Backups are AES-256-GCM encrypted. Before production release, configure a
private release keystore and complete the Play data-safety and privacy forms.

## Current scope

Loans, investments, savings goals, OCR, voice entry, WhatsApp reports, and AI
budgeting are intentionally reserved for post-MVP development.

No open-source license has been granted yet. Public visibility does not grant
permission to copy, modify, or redistribute this code.
