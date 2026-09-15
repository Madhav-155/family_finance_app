import 'dart:io';

import 'package:family_finance_app/sync/sync_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('member invite accepts an app Sheet URL', () {
    expect(
      parseSpreadsheetId(
        'https://docs.google.com/spreadsheets/d/'
        '1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890/edit',
      ),
      '1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890',
    );
  });

  test('invalid member invite receives an actionable error', () {
    expect(
      () => parseSpreadsheetId('not-a-sheet'),
      throwsA(
        isA<SyncFailure>().having(
          (failure) => failure.kind,
          'kind',
          SyncFailureKind.invalidHousehold,
        ),
      ),
    );
  });

  test('offline failures preserve completed setup access', () {
    final failure = SyncFailure.from(
      const SocketException('Failed host lookup'),
    );

    expect(failure.kind, SyncFailureKind.offline);
    expect(failure.invalidatesCompletedSetup, isFalse);
    expect(failure.userMessage, contains('local'));
  });

  test('missing Android Google account has actionable guidance', () {
    final failure = SyncFailure.from(
      Exception('No credential available: No credentials available'),
    );

    expect(failure.kind, SyncFailureKind.noGoogleAccount);
    expect(failure.userMessage, contains('Android Settings'));
    expect(failure.invalidatesCompletedSetup, isFalse);
  });

  test('revoked credentials lock setup until reconnect', () {
    final failure = SyncFailure.from(
      Exception('401 unauthenticated: invalid credentials'),
    );

    expect(failure.kind, SyncFailureKind.accessRevoked);
    expect(failure.invalidatesCompletedSetup, isTrue);
  });

  test('disabled Google API has specific guidance', () {
    final failure = SyncFailure.from(
      Exception('403 SERVICE_DISABLED accessNotConfigured'),
    );

    expect(failure.kind, SyncFailureKind.apiDisabled);
    expect(failure.userMessage, contains('Enable both Google Sheets API'));
  });

  test('OAuth test-user denial has specific guidance', () {
    final failure = SyncFailure.from(
      Exception('403: Access blocked - not a test user access_denied'),
    );

    expect(failure.kind, SyncFailureKind.testUserDenied);
    expect(failure.userMessage, contains('Test users'));
  });

  test('setup record retains separate member Google identity', () {
    final record = SetupRecord(
      role: HouseholdSetupRole.member,
      email: 'member@example.com',
      spreadsheetId: '1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890',
      householdId: 'family',
      completedAt: DateTime.utc(2026, 9, 15),
    );

    final decoded = SetupRecord.fromJson(record.toJson());

    expect(decoded.role, HouseholdSetupRole.member);
    expect(decoded.email, 'member@example.com');
  });
}
