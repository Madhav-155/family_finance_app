import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../services/backup_service.dart';
import '../../sync/google_sheets_sync_service.dart';
import '../../sync/sync_contracts.dart';
import '../data/finance_repository.dart';
import '../domain/finance_models.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => ref.read(databaseProvider),
);
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.read(databaseProvider)),
);
final syncServiceProvider = Provider<FamilySyncService>(
  (ref) => GoogleSheetsSyncService(ref.read(databaseProvider)),
);

final financeProvider =
    AsyncNotifierProvider<FinanceController, FinanceSnapshot>(
      FinanceController.new,
    );

class FinanceController extends AsyncNotifier<FinanceSnapshot> {
  static const _uuid = Uuid();

  FinanceRepository get _repository => ref.read(financeRepositoryProvider);

  @override
  Future<FinanceSnapshot> build() => _repository.loadSnapshot();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.loadSnapshot);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      state = AsyncData(await _repository.loadSnapshot());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> addExpense({
    required int amountMinor,
    required String category,
    required String paidBy,
    required String paymentMode,
    required DateTime date,
    required String notes,
  }) {
    final now = DateTime.now();
    final id = _uuid.v4();
    return _mutate(
      () => _repository.insertEntity(
        'expenses',
        Expense(
          id: id,
          householdId: AppDatabase.householdId,
          createdBy: AppDatabase.localUserId,
          deviceId: _repository.deviceId,
          createdAt: now,
          updatedAt: now,
          revision: 1,
          deleted: false,
          amountMinor: amountMinor,
          category: category,
          paidBy: paidBy,
          paymentMode: paymentMode,
          date: date,
          notes: notes,
        ).toMap(),
      ),
    );
  }

  Future<void> addIncome({
    required String source,
    required int amountMinor,
    required DateTime receivedDate,
  }) {
    final now = DateTime.now();
    final id = _uuid.v4();
    return _mutate(
      () => _repository.insertEntity(
        'income',
        IncomeEntry(
          id: id,
          householdId: AppDatabase.householdId,
          createdBy: AppDatabase.localUserId,
          deviceId: _repository.deviceId,
          createdAt: now,
          updatedAt: now,
          revision: 1,
          deleted: false,
          source: source,
          amountMinor: amountMinor,
          receivedDate: receivedDate,
        ).toMap(),
      ),
    );
  }

  Future<Emi> addEmi({
    required String loanName,
    required int amountMinor,
    required DateTime dueDate,
  }) async {
    final now = DateTime.now();
    final emi = Emi(
      id: _uuid.v4(),
      householdId: AppDatabase.householdId,
      createdBy: AppDatabase.localUserId,
      deviceId: _repository.deviceId,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deleted: false,
      loanName: loanName,
      amountMinor: amountMinor,
      dueDate: dueDate,
      paid: false,
    );
    await _mutate(() => _repository.insertEntity('emis', emi.toMap()));
    return emi;
  }

  Future<void> markEmiPaid(Emi emi) =>
      _mutate(() => _repository.markEmiPaid(emi));

  Future<void> addBudget({
    required String category,
    required int limitMinor,
    required String month,
  }) {
    final now = DateTime.now();
    final existing = state.value?.budgets
        .where(
          (item) =>
              !item.deleted && item.category == category && item.month == month,
        )
        .firstOrNull;
    final budget = Budget(
      id: existing?.id ?? _uuid.v4(),
      householdId: AppDatabase.householdId,
      createdBy: AppDatabase.localUserId,
      deviceId: _repository.deviceId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      revision: existing?.revision ?? 1,
      deleted: false,
      category: category,
      limitMinor: limitMinor,
      month: month,
    );
    return _mutate(
      () => existing == null
          ? _repository.insertEntity('budgets', budget.toMap())
          : _repository.updateEntity('budgets', existing, budget.toMap()),
    );
  }

  Future<void> deleteExpense(Expense expense) =>
      _mutate(() => _repository.deleteEntity('expenses', expense));

  Future<void> deleteIncome(IncomeEntry income) =>
      _mutate(() => _repository.deleteEntity('income', income));

  Future<void> updateExpense(
    Expense expense, {
    required int amountMinor,
    required String category,
    required String paidBy,
    required String paymentMode,
    required DateTime date,
    required String notes,
  }) {
    final updated = Expense(
      id: expense.id,
      householdId: expense.householdId,
      createdBy: expense.createdBy,
      deviceId: _repository.deviceId,
      createdAt: expense.createdAt,
      updatedAt: DateTime.now(),
      revision: expense.revision,
      deleted: false,
      amountMinor: amountMinor,
      category: category,
      paidBy: paidBy,
      paymentMode: paymentMode,
      date: date,
      notes: notes,
    );
    return _mutate(
      () => _repository.updateEntity('expenses', expense, updated.toMap()),
    );
  }

  Future<void> updateIncome(
    IncomeEntry income, {
    required String source,
    required int amountMinor,
    required DateTime receivedDate,
  }) {
    final updated = IncomeEntry(
      id: income.id,
      householdId: income.householdId,
      createdBy: income.createdBy,
      deviceId: _repository.deviceId,
      createdAt: income.createdAt,
      updatedAt: DateTime.now(),
      revision: income.revision,
      deleted: false,
      source: source,
      amountMinor: amountMinor,
      receivedDate: receivedDate,
    );
    return _mutate(
      () => _repository.updateEntity('income', income, updated.toMap()),
    );
  }
}

class AppSettingsState {
  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.largeText = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool largeText;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? largeText,
  }) => AppSettingsState(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    largeText: largeText ?? this.largeText,
  );
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );

abstract interface class AppSettingsStorage {
  Future<AppSettingsState?> read();
  Future<void> write(AppSettingsState value);
}

class SecureAppSettingsStorage implements AppSettingsStorage {
  const SecureAppSettingsStorage();

  static const _storage = FlutterSecureStorage();
  static const _themeKey = 'settings_theme';
  static const _localeKey = 'settings_locale';
  static const _largeTextKey = 'settings_large_text';

  @override
  Future<AppSettingsState?> read() async {
    final values = await _storage.readAll();
    if (!values.containsKey(_themeKey) &&
        !values.containsKey(_localeKey) &&
        !values.containsKey(_largeTextKey)) {
      return null;
    }
    return AppSettingsState(
      themeMode: switch (values[_themeKey]) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      locale: Locale(values[_localeKey] == 'te' ? 'te' : 'en'),
      largeText: values[_largeTextKey] == 'true',
    );
  }

  @override
  Future<void> write(AppSettingsState value) async {
    await Future.wait([
      _storage.write(key: _themeKey, value: value.themeMode.name),
      _storage.write(key: _localeKey, value: value.locale.languageCode),
      _storage.write(key: _largeTextKey, value: '${value.largeText}'),
    ]);
  }
}

final appSettingsStorageProvider = Provider<AppSettingsStorage>(
  (ref) => const SecureAppSettingsStorage(),
);

class AppSettingsController extends Notifier<AppSettingsState> {
  bool _changed = false;

  @override
  AppSettingsState build() {
    unawaited(_restore());
    return const AppSettingsState();
  }

  void toggleDarkMode(bool enabled) {
    _changed = true;
    state = state.copyWith(
      themeMode: enabled ? ThemeMode.dark : ThemeMode.light,
    );
    unawaited(_persist());
  }

  void setLocale(String languageCode) {
    _changed = true;
    state = state.copyWith(locale: Locale(languageCode));
    unawaited(_persist());
  }

  void toggleLargeText(bool enabled) {
    _changed = true;
    state = state.copyWith(largeText: enabled);
    unawaited(_persist());
  }

  Future<void> _restore() async {
    try {
      final saved = await ref.read(appSettingsStorageProvider).read();
      if (ref.mounted && saved != null && !_changed) state = saved;
    } on Object {
      // Defaults remain usable when secure storage is temporarily unavailable.
    }
  }

  Future<void> _persist() async {
    try {
      await ref.read(appSettingsStorageProvider).write(state);
    } on Object {
      // A settings write must never block finance features.
    }
  }
}
