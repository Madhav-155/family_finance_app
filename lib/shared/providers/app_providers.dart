import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../services/backup_service.dart';
import '../../sync/google_sheets_sync_service.dart';
import '../domain/finance_models.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.read(databaseProvider)),
);
final syncServiceProvider = Provider<GoogleSheetsSyncService>(
  (ref) => GoogleSheetsSyncService(ref.read(databaseProvider))..initialize(),
);

final financeProvider =
    AsyncNotifierProvider<FinanceController, FinanceSnapshot>(
      FinanceController.new,
    );

class FinanceController extends AsyncNotifier<FinanceSnapshot> {
  static const _uuid = Uuid();

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  Future<FinanceSnapshot> build() => _db.loadSnapshot();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_db.loadSnapshot);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      state = AsyncData(await _db.loadSnapshot());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
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
      () => _db.insertEntity(
        'expenses',
        Expense(
          id: id,
          householdId: AppDatabase.householdId,
          createdBy: AppDatabase.localUserId,
          deviceId: _db.deviceId,
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
      () => _db.insertEntity(
        'income',
        IncomeEntry(
          id: id,
          householdId: AppDatabase.householdId,
          createdBy: AppDatabase.localUserId,
          deviceId: _db.deviceId,
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
      deviceId: _db.deviceId,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deleted: false,
      loanName: loanName,
      amountMinor: amountMinor,
      dueDate: dueDate,
      paid: false,
    );
    await _mutate(() => _db.insertEntity('emis', emi.toMap()));
    return emi;
  }

  Future<void> markEmiPaid(Emi emi) => _mutate(() => _db.markEmiPaid(emi));

  Future<void> addBudget({
    required String category,
    required int limitMinor,
    required String month,
  }) {
    final now = DateTime.now();
    final budget = Budget(
      id: _uuid.v4(),
      householdId: AppDatabase.householdId,
      createdBy: AppDatabase.localUserId,
      deviceId: _db.deviceId,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deleted: false,
      category: category,
      limitMinor: limitMinor,
      month: month,
    );
    return _mutate(() => _db.insertEntity('budgets', budget.toMap()));
  }

  Future<void> deleteExpense(Expense expense) =>
      _mutate(() => _db.deleteEntity('expenses', expense));

  Future<void> deleteIncome(IncomeEntry income) =>
      _mutate(() => _db.deleteEntity('income', income));
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

class AppSettingsController extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() => const AppSettingsState();

  void toggleDarkMode(bool enabled) {
    state = state.copyWith(
      themeMode: enabled ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setLocale(String languageCode) {
    state = state.copyWith(locale: Locale(languageCode));
  }

  void toggleLargeText(bool enabled) {
    state = state.copyWith(largeText: enabled);
  }
}
