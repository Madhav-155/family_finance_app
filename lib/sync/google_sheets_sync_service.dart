import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../database/app_database.dart';
import 'sync_contracts.dart';

class GoogleSheetsSyncService implements FamilySyncService {
  GoogleSheetsSyncService(this.database);

  final AppDatabase database;
  static const _storage = FlutterSecureStorage();
  static const _spreadsheetKey = 'household_spreadsheet_id';
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '424931751635-0dvuphu0ir9lona5vf28uk8dnt9aomm5.apps.googleusercontent.com',
  );
  static const _scopes = [
    sheets.SheetsApi.spreadsheetsScope,
    drive.DriveApi.driveFileScope,
  ];
  static const _columns = <String, List<String>>{
    'expenses': [
      'id',
      'household_id',
      'created_by',
      'device_id',
      'created_at',
      'updated_at',
      'revision',
      'is_deleted',
      'sync_state',
      'amount_minor',
      'category',
      'paid_by',
      'payment_mode',
      'date',
      'notes',
    ],
    'income': [
      'id',
      'household_id',
      'created_by',
      'device_id',
      'created_at',
      'updated_at',
      'revision',
      'is_deleted',
      'sync_state',
      'source',
      'amount_minor',
      'received_date',
    ],
    'emis': [
      'id',
      'household_id',
      'created_by',
      'device_id',
      'created_at',
      'updated_at',
      'revision',
      'is_deleted',
      'sync_state',
      'loan_name',
      'amount_minor',
      'due_date',
      'status',
    ],
    'budgets': [
      'id',
      'household_id',
      'created_by',
      'device_id',
      'created_at',
      'updated_at',
      'revision',
      'is_deleted',
      'sync_state',
      'category',
      'limit_minor',
      'month',
    ],
  };

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? _account;
  bool _initialized = false;
  SyncStatus _status = const SyncStatus();

  @override
  Stream<SyncStatus> get statuses => _statusController.stream;
  @override
  SyncStatus get status => _status;
  @override
  String? get signedInEmail => _account?.email;

  void _emit(SyncStatus value) {
    _status = value;
    _statusController.add(value);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (!_serverClientId.endsWith('.apps.googleusercontent.com')) {
      throw const SyncFailure(
        kind: SyncFailureKind.oauthMisconfigured,
        userMessage: 'This app build has an invalid Google Web client ID. Install a correctly configured build or contact the app owner.',
        diagnostic: 'initialize: GOOGLE_SERVER_CLIENT_ID is invalid',
      );
    }
    await _googleSignIn.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
    final spreadsheetId = await _storage.read(key: _spreadsheetKey);
    _emit(SyncStatus(spreadsheetId: spreadsheetId));
    _googleSignIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _account = event.user;
          _emit(
            SyncStatus(
              signedInEmail: event.user.email,
              spreadsheetId: _status.spreadsheetId,
              lastSyncedAt: _status.lastSyncedAt,
            ),
          );
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _account = null;
          _emit(SyncStatus(spreadsheetId: _status.spreadsheetId));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleFailure(error, operation: 'Google authentication event');
      },
    );
    try {
      final attempt = _googleSignIn.attemptLightweightAuthentication();
      if (attempt != null) _account = await attempt;
    } on Object catch (error) {
      final failure = SyncFailure.from(error, operation: 'restore sign-in');
      _debugFailure(failure);
      _emit(
        SyncStatus(
          spreadsheetId: spreadsheetId,
          message: failure.userMessage,
          failure: failure,
        ),
      );
    }
  }

  @override
  Future<SyncStatus> signIn({String? expectedEmail}) async {
    try {
      await initialize();
      _account = await _googleSignIn.authenticate(scopeHint: _scopes);
      if (expectedEmail != null &&
          _account!.email.toLowerCase() != expectedEmail.toLowerCase()) {
        throw const SyncFailure(
          kind: SyncFailureKind.accountMismatch,
          userMessage: 'Choose the same Google account that originally configured this household.',
          diagnostic: 'sign-in: authenticated account mismatch',
        );
      }
      _emit(
        SyncStatus(
          signedInEmail: _account!.email,
          spreadsheetId: _status.spreadsheetId,
          message: 'Google account connected.',
        ),
      );
      return _status;
    } on Object catch (error) {
      throw _handleFailure(error, operation: 'Google sign-in');
    }
  }

  @override
  Future<void> signOut() async {
    await initialize();
    await _googleSignIn.signOut();
    _account = null;
    _emit(SyncStatus(spreadsheetId: _status.spreadsheetId));
  }

  @override
  Future<SyncStatus> syncNow({SetupRecord? setup}) async {
    await initialize();
    final spreadsheetId = setup?.spreadsheetId ?? _status.spreadsheetId;
    if (spreadsheetId == null) {
      throw const SyncFailure(
        kind: SyncFailureKind.invalidHousehold,
        userMessage: 'Complete household setup before syncing finance data.',
        diagnostic: 'sync: no configured spreadsheet',
      );
    }
    if (_account == null) {
      await signIn(expectedEmail: setup?.email);
    } else if (setup != null &&
        _account!.email.toLowerCase() != setup.email.toLowerCase()) {
      throw const SyncFailure(
        kind: SyncFailureKind.accountMismatch,
        userMessage: 'This device is signed in with a different Google account. Reconnect the account used during setup.',
        diagnostic: 'sync: account mismatch',
      );
    }
    _emit(
      SyncStatus(
        signedInEmail: _account!.email,
        spreadsheetId: spreadsheetId,
        syncing: true,
      ),
    );
    try {
      final authorization = await _account!.authorizationClient.authorizeScopes(
        _scopes,
      );
      final client = authorization.authClient(scopes: _scopes);
      try {
        final sheetsApi = sheets.SheetsApi(client);
        await _pull(sheetsApi, spreadsheetId);
        await _push(sheetsApi, spreadsheetId);
        await database.markSynced();
        await _storage.write(key: _spreadsheetKey, value: spreadsheetId);
        _emit(
          SyncStatus(
            signedInEmail: _account!.email,
            spreadsheetId: spreadsheetId,
            lastSyncedAt: DateTime.now(),
            message: 'Family data is up to date.',
          ),
        );
      } finally {
        client.close();
      }
    } on Object catch (error) {
      throw _handleFailure(error, operation: 'family sync');
    }
    return _status;
  }

  @override
  Future<SetupRecord> createOwnerHousehold({
    required String householdName,
    List<String> memberEmails = const [],
  }) async {
    try {
      await signIn();
      final authorization = await _account!.authorizationClient.authorizeScopes(
        _scopes,
      );
      final client = authorization.authClient(scopes: _scopes);
      try {
        final sheetsApi = sheets.SheetsApi(client);
        final spreadsheetId = await _createSpreadsheet(
          sheetsApi,
          householdName: householdName,
        );
        await _push(sheetsApi, spreadsheetId);
        for (final email in memberEmails) {
          await _shareWithClient(client, spreadsheetId, email);
        }
        await database.markSynced();
        await _storage.write(key: _spreadsheetKey, value: spreadsheetId);
        final record = SetupRecord(
          role: HouseholdSetupRole.owner,
          email: _account!.email,
          spreadsheetId: spreadsheetId,
          householdId: AppDatabase.householdId,
          completedAt: DateTime.now().toUtc(),
          lastValidatedAt: DateTime.now().toUtc(),
        );
        _emit(
          SyncStatus(
            signedInEmail: record.email,
            spreadsheetId: spreadsheetId,
            lastSyncedAt: record.completedAt,
            message: 'Household created and initial sync completed.',
          ),
        );
        return record;
      } finally {
        client.close();
      }
    } on Object catch (error) {
      throw _handleFailure(error, operation: 'create household');
    }
  }

  @override
  Future<SetupRecord> joinMemberHousehold(String spreadsheetInput) async {
    try {
      final spreadsheetId = parseSpreadsheetId(spreadsheetInput);
      await signIn();
      final authorization = await _account!.authorizationClient.authorizeScopes(
        _scopes,
      );
      final client = authorization.authClient(scopes: _scopes);
      try {
        final sheetsApi = sheets.SheetsApi(client);
        final householdId = await _validateHouseholdSheet(
          sheetsApi,
          spreadsheetId,
        );
        await _pull(sheetsApi, spreadsheetId);
        await database.markSynced();
        await _storage.write(key: _spreadsheetKey, value: spreadsheetId);
        final record = SetupRecord(
          role: HouseholdSetupRole.member,
          email: _account!.email,
          spreadsheetId: spreadsheetId,
          householdId: householdId,
          completedAt: DateTime.now().toUtc(),
          lastValidatedAt: DateTime.now().toUtc(),
        );
        _emit(
          SyncStatus(
            signedInEmail: record.email,
            spreadsheetId: spreadsheetId,
            lastSyncedAt: record.completedAt,
            message: 'Joined the shared household successfully.',
          ),
        );
        return record;
      } finally {
        client.close();
      }
    } on Object catch (error) {
      throw _handleFailure(error, operation: 'join household');
    }
  }

  @override
  Future<void> validateSetup(SetupRecord setup) async {
    try {
      await initialize();
      if (_account == null) {
        final attempt = _googleSignIn.attemptLightweightAuthentication();
        if (attempt != null) _account = await attempt;
      }
      if (_account == null) {
        throw const SyncFailure(
          kind: SyncFailureKind.canceled,
          userMessage: 'Google could not silently restore the account. Local access remains available; reconnect before the next sync.',
          diagnostic: 'validation: no restorable authenticated account',
        );
      }
      if (_account!.email.toLowerCase() != setup.email.toLowerCase()) {
        throw const SyncFailure(
          kind: SyncFailureKind.accountMismatch,
          userMessage: 'The signed-in Google account does not match this household setup.',
          diagnostic: 'validation: account mismatch',
        );
      }
      final authorization = await _account!.authorizationClient
          .authorizationForScopes(_scopes);
      if (authorization == null) {
        throw const SyncFailure(
          kind: SyncFailureKind.accessRevoked,
          userMessage: 'Google permissions were removed. Reconnect to continue family sync.',
          diagnostic: 'validation: scopes not authorized',
        );
      }
      final client = authorization.authClient(scopes: _scopes);
      try {
        await _validateHouseholdSheet(
          sheets.SheetsApi(client),
          setup.spreadsheetId,
        );
      } finally {
        client.close();
      }
    } on Object catch (error) {
      throw _handleFailure(error, operation: 'validate household');
    }
  }

  Future<String> _createSpreadsheet(
    sheets.SheetsApi api, {
    required String householdName,
  }) async {
    final response = await api.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: 'Family Finance - $householdName',
        ),
        sheets: [
          for (final table in _columns.keys)
            sheets.Sheet(properties: sheets.SheetProperties(title: table)),
          sheets.Sheet(properties: sheets.SheetProperties(title: '_schema')),
        ],
      ),
    );
    final id = response.spreadsheetId;
    if (id == null) throw StateError('Google did not return a spreadsheet ID.');
    await api.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['schema_version', '1'],
          ['household_id', AppDatabase.householdId],
        ],
      ),
      id,
      "'_schema'!A1:B2",
      valueInputOption: 'RAW',
    );
    return id;
  }

  Future<String> _validateHouseholdSheet(
    sheets.SheetsApi api,
    String spreadsheetId,
  ) async {
    final response = await api.spreadsheets.values.get(
      spreadsheetId,
      "'_schema'!A1:B10",
    );
    final values = response.values ?? const <List<Object?>>[];
    final schema = <String, String>{
      for (final row in values)
        if (row.length >= 2) '${row[0]}': '${row[1]}',
    };
    if (schema['schema_version'] != '1' ||
        (schema['household_id']?.isEmpty ?? true)) {
      throw const SyncFailure(
        kind: SyncFailureKind.invalidHousehold,
        userMessage: 'This Sheet is not a valid Family Finance household. Ask the owner for the app-created Sheet link.',
        diagnostic: 'validation: missing or unsupported schema',
      );
    }
    return schema['household_id']!;
  }

  Future<void> _pull(sheets.SheetsApi api, String spreadsheetId) async {
    for (final entry in _columns.entries) {
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        "'${entry.key}'!A:Z",
      );
      final values = response.values ?? const <List<Object?>>[];
      if (values.length < 2) continue;
      final headers = values.first.map((value) => '$value').toList();
      await database.mergeRemoteRows(
        entry.key,
        headers,
        values.skip(1).toList(),
      );
    }
  }

  Future<void> _push(sheets.SheetsApi api, String spreadsheetId) async {
    final data = await database.exportData();
    for (final entry in _columns.entries) {
      final columns = entry.value;
      final rows = data[entry.key] ?? const [];
      final values = <List<Object?>>[
        columns,
        for (final row in rows)
          [for (final column in columns) row[column] ?? ''],
      ];
      final range = "'${entry.key}'!A:Z";
      await api.spreadsheets.values.clear(
        sheets.ClearValuesRequest(),
        spreadsheetId,
        range,
      );
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: values),
        spreadsheetId,
        "'${entry.key}'!A1",
        valueInputOption: 'RAW',
      );
    }
  }

  @override
  Future<void> shareWith(String email) async {
    try {
      final id = _status.spreadsheetId;
      if (id == null) {
        throw const SyncFailure(
          kind: SyncFailureKind.invalidHousehold,
          userMessage: 'Complete owner setup before inviting family members.',
          diagnostic: 'share: no configured spreadsheet',
        );
      }
      if (_account == null) await signIn();
      final authorization = await _account!.authorizationClient.authorizeScopes(
        _scopes,
      );
      final client = authorization.authClient(scopes: _scopes);
      try {
        await _shareWithClient(client, id, email);
      } finally {
        client.close();
      }
    } on Object catch (error) {
      throw _handleFailure(error, operation: 'share household');
    }
  }

  Future<void> _shareWithClient(
    dynamic client,
    String spreadsheetId,
    String email,
  ) async {
    await drive.DriveApi(client).permissions.create(
      drive.Permission(type: 'user', role: 'writer', emailAddress: email),
      spreadsheetId,
      sendNotificationEmail: true,
    );
  }

  SyncFailure _handleFailure(Object error, {required String operation}) {
    final failure = SyncFailure.from(error, operation: operation);
    _debugFailure(failure);
    _emit(
      SyncStatus(
        signedInEmail: _account?.email,
        spreadsheetId: _status.spreadsheetId,
        lastSyncedAt: _status.lastSyncedAt,
        message: failure.userMessage,
        failure: failure,
      ),
    );
    return failure;
  }

  void _debugFailure(SyncFailure failure) {
    if (kDebugMode) {
      debugPrint('FamilySync ${failure.kind.name}: ${failure.diagnostic}');
    }
  }
}
