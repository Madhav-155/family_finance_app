import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum HouseholdSetupRole { owner, member }

class SyncStatus {
  const SyncStatus({
    this.signedInEmail,
    this.spreadsheetId,
    this.lastSyncedAt,
    this.syncing = false,
    this.message,
    this.failure,
  });

  final String? signedInEmail;
  final String? spreadsheetId;
  final DateTime? lastSyncedAt;
  final bool syncing;
  final String? message;
  final SyncFailure? failure;
}

class SetupRecord {
  const SetupRecord({
    required this.role,
    required this.email,
    required this.spreadsheetId,
    required this.householdId,
    required this.completedAt,
    this.lastValidatedAt,
  });

  final HouseholdSetupRole role;
  final String email;
  final String spreadsheetId;
  final String householdId;
  final DateTime completedAt;
  final DateTime? lastValidatedAt;

  SetupRecord copyWith({DateTime? lastValidatedAt}) => SetupRecord(
    role: role,
    email: email,
    spreadsheetId: spreadsheetId,
    householdId: householdId,
    completedAt: completedAt,
    lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
  );

  Map<String, Object?> toJson() => {
    'role': role.name,
    'email': email,
    'spreadsheetId': spreadsheetId,
    'householdId': householdId,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'lastValidatedAt': lastValidatedAt?.toUtc().toIso8601String(),
  };

  factory SetupRecord.fromJson(Map<String, dynamic> json) => SetupRecord(
    role: HouseholdSetupRole.values.byName(json['role'] as String),
    email: json['email'] as String,
    spreadsheetId: json['spreadsheetId'] as String,
    householdId: json['householdId'] as String,
    completedAt: DateTime.parse(json['completedAt'] as String),
    lastValidatedAt: json['lastValidatedAt'] == null
        ? null
        : DateTime.parse(json['lastValidatedAt'] as String),
  );
}

class SetupStorage {
  const SetupStorage();

  static const _storage = FlutterSecureStorage();
  static const _recordKey = 'family_setup_record_v1';

  Future<SetupRecord?> read() async {
    final value = await _storage.read(key: _recordKey);
    if (value == null) return null;
    try {
      return SetupRecord.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write(SetupRecord record) =>
      _storage.write(key: _recordKey, value: jsonEncode(record.toJson()));

  Future<void> clear() => _storage.delete(key: _recordKey);
}

abstract interface class FamilySyncService {
  Stream<SyncStatus> get statuses;
  SyncStatus get status;
  String? get signedInEmail;

  Future<void> initialize();
  Future<SyncStatus> signIn({String? expectedEmail});
  Future<void> signOut();
  Future<SyncStatus> syncNow({SetupRecord? setup});
  Future<SetupRecord> createOwnerHousehold({
    required String householdName,
    List<String> memberEmails = const [],
  });
  Future<SetupRecord> joinMemberHousehold(String spreadsheetInput);
  Future<void> validateSetup(SetupRecord setup);
  Future<void> shareWith(String email);
}

enum SyncFailureKind {
  canceled,
  noGoogleAccount,
  offline,
  oauthMisconfigured,
  testUserDenied,
  apiDisabled,
  accessRevoked,
  accountMismatch,
  invalidHousehold,
  unknown,
}

class SyncFailure implements Exception {
  const SyncFailure({
    required this.kind,
    required this.userMessage,
    required this.diagnostic,
  });

  final SyncFailureKind kind;
  final String userMessage;
  final String diagnostic;

  bool get invalidatesCompletedSetup =>
      kind == SyncFailureKind.accessRevoked ||
      kind == SyncFailureKind.accountMismatch ||
      kind == SyncFailureKind.invalidHousehold;

  static SyncFailure from(Object error, {String operation = 'sync'}) {
    if (error is SyncFailure) return error;
    if (error is SocketException || error is TimeoutException) {
      return SyncFailure(
        kind: SyncFailureKind.offline,
        userMessage: 'No network connection. Your existing local finance data is still available; reconnect and retry sync.',
        diagnostic: '$operation: ${error.runtimeType}',
      );
    }
    if (error is GoogleSignInException) {
      final description = error.description ?? '';
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => SyncFailure(
          kind: SyncFailureKind.canceled,
          userMessage: 'Google sign-in was canceled. Choose an account and approve access to continue.',
          diagnostic: '$operation: ${error.code.name}: $description',
        ),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError => SyncFailure(
          kind: SyncFailureKind.oauthMisconfigured,
          userMessage: 'Google sign-in is not configured for this app build. Check the Android package, SHA fingerprint, and Web client ID.',
          diagnostic: '$operation: ${error.code.name}: $description',
        ),
        GoogleSignInExceptionCode.userMismatch => SyncFailure(
          kind: SyncFailureKind.accountMismatch,
          userMessage: 'This household was set up with a different Google account. Sign in with the original account for this device.',
          diagnostic: '$operation: userMismatch: $description',
        ),
        _ => _fromText(error.toString(), operation: operation),
      };
    }
    return _fromText(error.toString(), operation: operation);
  }

  static SyncFailure _fromText(String value, {required String operation}) {
    final text = value.toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection timed out') ||
        text.contains('network_error') ||
        text.contains('network error') ||
        text.contains('statuscode: 7') ||
        text.contains('status code 7')) {
      return SyncFailure(
        kind: SyncFailureKind.offline,
        userMessage: 'No network connection. Local data remains usable; reconnect and retry sync.',
        diagnostic: '$operation: network unavailable',
      );
    }
    if (text.contains('no credential available') ||
        text.contains('no credentials available')) {
      return SyncFailure(
        kind: SyncFailureKind.noGoogleAccount,
        userMessage: 'No Google account is available on this Android device. Add an account in Android Settings, then retry.',
        diagnostic: '$operation: Android Credential Manager has no account',
      );
    }
    if (text.contains('access_denied') ||
        text.contains('not a test user') ||
        text.contains('403: access blocked') ||
        text.contains('org_internal') ||
        text.contains('app is blocked')) {
      return SyncFailure(
        kind: SyncFailureKind.testUserDenied,
        userMessage: 'This Google account is not allowed to use the OAuth test app. Add it under OAuth consent screen → Test users.',
        diagnostic: '$operation: OAuth access denied',
      );
    }
    if (text.contains('api has not been used') ||
        text.contains('accessnotconfigured') ||
        text.contains('service_disabled') ||
        text.contains('service disabled')) {
      return SyncFailure(
        kind: SyncFailureKind.apiDisabled,
        userMessage: 'Enable both Google Sheets API and Google Drive API for the configured Cloud project, then retry.',
        diagnostic: '$operation: required Google API disabled',
      );
    }
    if (text.contains('401') ||
        text.contains('invalid credentials') ||
        text.contains('unauthenticated') ||
        text.contains('insufficient authentication scopes')) {
      return SyncFailure(
        kind: SyncFailureKind.accessRevoked,
        userMessage: 'Google access has expired or was revoked. Reconnect your account to restore family sync.',
        diagnostic: '$operation: authorization revoked',
      );
    }
    if (text.contains('developer_error') ||
        text.contains('statuscode: 10') ||
        text.contains('status code 10') ||
        text.contains('client configuration') ||
        text.contains('provider configuration') ||
        text.contains('server client id') ||
        text.contains('oauth client')) {
      return SyncFailure(
        kind: SyncFailureKind.oauthMisconfigured,
        userMessage: 'Google sign-in is not configured for this app build. In Google Cloud, add an Android OAuth client for package com.madhav.family_finance_app with this build’s SHA-1, and keep the Web client ID in the same project.',
        diagnostic: '$operation: OAuth client configuration mismatch',
      );
    }
    if (text.contains('404') ||
        text.contains('not found') ||
        text.contains('permission denied') ||
        text.contains('forbidden')) {
      return SyncFailure(
        kind: SyncFailureKind.invalidHousehold,
        userMessage: 'The household spreadsheet was not found or is not shared with this Google account.',
        diagnostic: '$operation: spreadsheet unavailable',
      );
    }
    return SyncFailure(
      kind: SyncFailureKind.unknown,
      userMessage: 'Family sync could not be completed. Check Google setup and try again.',
      diagnostic: '$operation: ${_redact(value)}',
    );
  }

  static String _redact(String value) => value
      .replaceAll(RegExp(r'ya29\.[A-Za-z0-9._-]+'), '[token]')
      .replaceAll(
        RegExp(r'Bearer\s+\S+', caseSensitive: false),
        'Bearer [token]',
      );

  @override
  String toString() => userMessage;
}

String parseSpreadsheetId(String input) {
  final value = input.trim();
  final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(value);
  final id = match?.group(1) ?? value;
  if (!RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(id)) {
    throw const SyncFailure(
      kind: SyncFailureKind.invalidHousehold,
      userMessage: 'Enter a valid Google Sheets link or spreadsheet ID from the household owner.',
      diagnostic: 'join: invalid spreadsheet identifier',
    );
  }
  return id;
}
