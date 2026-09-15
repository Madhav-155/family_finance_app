import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../database/app_database.dart';

class SyncStatus {
  const SyncStatus({
    this.signedInEmail,
    this.spreadsheetId,
    this.lastSyncedAt,
    this.syncing = false,
    this.message,
  });

  final String? signedInEmail;
  final String? spreadsheetId;
  final DateTime? lastSyncedAt;
  final bool syncing;
  final String? message;
}

class GoogleSheetsSyncService {
  GoogleSheetsSyncService(this.database);

  final AppDatabase database;
  static const _storage = FlutterSecureStorage();
  static const _spreadsheetKey = 'household_spreadsheet_id';
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
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

  Stream<SyncStatus> get statuses => _statusController.stream;
  SyncStatus get status => _status;

  void _emit(SyncStatus value) {
    _status = value;
    _statusController.add(value);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
    final spreadsheetId = await _storage.read(key: _spreadsheetKey);
    _emit(SyncStatus(spreadsheetId: spreadsheetId));
    _googleSignIn.authenticationEvents.listen((event) {
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
    });
    final attempt = _googleSignIn.attemptLightweightAuthentication();
    if (attempt != null) _account = await attempt;
  }

  Future<SyncStatus> signIn() async {
    await initialize();
    _account = await _googleSignIn.authenticate(scopeHint: _scopes);
    _emit(
      SyncStatus(
        signedInEmail: _account!.email,
        spreadsheetId: _status.spreadsheetId,
      ),
    );
    return _status;
  }

  Future<void> signOut() async {
    await initialize();
    await _googleSignIn.signOut();
    _account = null;
    _emit(SyncStatus(spreadsheetId: _status.spreadsheetId));
  }

  Future<SyncStatus> syncNow() async {
    await initialize();
    _account ??= await _googleSignIn.authenticate(scopeHint: _scopes);
    _emit(
      SyncStatus(
        signedInEmail: _account!.email,
        spreadsheetId: _status.spreadsheetId,
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
        final spreadsheetId =
            _status.spreadsheetId ?? await _createSpreadsheet(sheetsApi);
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
    } catch (error) {
      _emit(
        SyncStatus(
          signedInEmail: _account?.email,
          spreadsheetId: _status.spreadsheetId,
          message: 'Sync failed: $error',
        ),
      );
      rethrow;
    }
    return _status;
  }

  Future<String> _createSpreadsheet(sheets.SheetsApi api) async {
    final response = await api.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: 'Family Finance - My Family',
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

  Future<void> shareWith(String email) async {
    final id = _status.spreadsheetId;
    if (id == null) throw StateError('Sync once before inviting family.');
    if (_account == null) await signIn();
    final authorization = await _account!.authorizationClient.authorizeScopes(
      _scopes,
    );
    final client = authorization.authClient(scopes: _scopes);
    try {
      await drive.DriveApi(client).permissions.create(
        drive.Permission(type: 'user', role: 'writer', emailAddress: email),
        id,
        sendNotificationEmail: true,
      );
    } finally {
      client.close();
    }
  }
}
