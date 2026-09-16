import 'package:family_finance_app/core/time/ist_time.dart';
import 'package:family_finance_app/shared/data/finance_repository.dart';
import 'package:family_finance_app/shared/domain/finance_models.dart';
import 'package:family_finance_app/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryFinanceRepository implements FinanceRepository {
  final records = <String, Map<String, JsonMap>>{
    'expenses': {},
    'income': {},
    'emis': {},
    'budgets': {},
  };

  @override
  String get deviceId => 'test-device';

  @override
  Future<void> insertEntity(String table, JsonMap values) async {
    records[table]![values['id']! as String] = Map.of(values);
  }

  @override
  Future<void> updateEntity(
    String table,
    SyncEntity entity,
    JsonMap values,
  ) async {
    records[table]![entity.id] = {
      ...values,
      'revision': entity.revision + 1,
      'is_deleted': 0,
    };
  }

  @override
  Future<void> deleteEntity(String table, SyncEntity entity) async {
    records[table]![entity.id] = {
      ...records[table]![entity.id]!,
      'revision': entity.revision + 1,
      'is_deleted': 1,
    };
  }

  @override
  Future<void> markEmiPaid(Emi emi) async {
    records['emis']![emi.id] = {
      ...records['emis']![emi.id]!,
      'revision': emi.revision + 1,
      'status': 'paid',
    };
  }

  @override
  Future<FinanceSnapshot> loadSnapshot() async => FinanceSnapshot(
    expenses: records['expenses']!.values.map(Expense.fromMap).toList(),
    income: records['income']!.values.map(IncomeEntry.fromMap).toList(),
    emis: records['emis']!.values.map(Emi.fromMap).toList(),
    budgets: records['budgets']!.values.map(Budget.fromMap).toList(),
  );
}

void main() {
  setUpAll(IstTime.initialize);

  test(
    'local finance workflow supports add, edit, delete, and totals',
    () async {
      final repository = _MemoryFinanceRepository();
      final container = ProviderContainer(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(financeProvider.future);
      final controller = container.read(financeProvider.notifier);
      final today = IstTime.dateOnly(IstTime.now());

      await controller.addIncome(
        source: 'Salary',
        amountMinor: 100000,
        receivedDate: today,
      );
      await controller.addExpense(
        amountMinor: 25000,
        category: 'Food',
        paidBy: 'owner@example.com',
        paymentMode: 'UPI',
        date: today,
        notes: '',
      );

      var snapshot = container.read(financeProvider).requireValue;
      expect(snapshot.monthlyIncome, 100000);
      expect(snapshot.monthlyExpenses, 25000);
      expect(snapshot.moneyLeft, 75000);

      await controller.updateIncome(
        snapshot.income.single,
        source: 'Updated salary',
        amountMinor: 120000,
        receivedDate: today,
      );
      await controller.updateExpense(
        snapshot.expenses.single,
        amountMinor: 30000,
        category: 'Bills',
        paidBy: 'owner@example.com',
        paymentMode: 'Bank',
        date: today,
        notes: 'Updated',
      );

      snapshot = container.read(financeProvider).requireValue;
      expect(snapshot.monthlyIncome, 120000);
      expect(snapshot.monthlyExpenses, 30000);
      expect(snapshot.categoryTotals, {'Bills': 30000});

      await controller.deleteExpense(snapshot.expenses.single);
      await controller.deleteIncome(snapshot.income.single);
      snapshot = container.read(financeProvider).requireValue;
      expect(snapshot.monthlyIncome, 0);
      expect(snapshot.monthlyExpenses, 0);
    },
  );

  test('budget upsert avoids duplicate category-month rows', () async {
    final repository = _MemoryFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(financeProvider.future);
    final controller = container.read(financeProvider.notifier);
    final month = FinanceSnapshot().currentMonth;

    await controller.addBudget(
      category: 'Food',
      limitMinor: 50000,
      month: month,
    );
    await controller.addBudget(
      category: 'Food',
      limitMinor: 75000,
      month: month,
    );

    final budgets = container
        .read(financeProvider)
        .requireValue
        .currentMonthBudgets
        .toList();
    expect(budgets, hasLength(1));
    expect(budgets.single.limitMinor, 75000);
  });

  test('paying an EMI does not incorrectly increase money left', () async {
    final repository = _MemoryFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(financeProvider.future);
    final controller = container.read(financeProvider.notifier);
    final today = IstTime.dateOnly(IstTime.now());

    await controller.addIncome(
      source: 'Salary',
      amountMinor: 100000,
      receivedDate: today,
    );
    final emi = await controller.addEmi(
      loanName: 'Home loan',
      amountMinor: 20000,
      dueDate: today,
    );
    final before = container.read(financeProvider).requireValue;
    expect(before.emiDue, 20000);
    expect(before.moneyLeft, 80000);

    await controller.markEmiPaid(emi);
    final after = container.read(financeProvider).requireValue;
    expect(after.emiDue, 0);
    expect(after.moneyLeft, 80000);
  });
}
