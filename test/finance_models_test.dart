import 'package:family_finance_app/shared/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money values are converted to integer minor units', () {
    expect(rupeesToMinor('1250.50'), 125050);
    expect(rupeesToMinor('invalid'), 0);
  });

  test('finance dates remain date-only across time zones', () {
    final date = DateTime(2026, 9);
    final income = IncomeEntry(
      id: 'income',
      householdId: 'family',
      createdBy: 'owner',
      deviceId: 'phone',
      createdAt: date,
      updatedAt: date,
      revision: 1,
      deleted: false,
      source: 'Salary',
      amountMinor: 10000,
      receivedDate: date,
    );

    expect(income.toMap()['received_date'], '2026-09-01');
  });

  test('monthly snapshot computes cash flow without floating point', () {
    final now = DateTime.now();
    final expense = Expense(
      id: 'expense',
      householdId: 'family',
      createdBy: 'owner',
      deviceId: 'phone',
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deleted: false,
      amountMinor: 250000,
      category: 'Food',
      paidBy: 'Owner',
      paymentMode: 'UPI',
      date: now,
      notes: '',
    );
    final income = IncomeEntry(
      id: 'income',
      householdId: 'family',
      createdBy: 'owner',
      deviceId: 'phone',
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deleted: false,
      source: 'Salary',
      amountMinor: 1000000,
      receivedDate: now,
    );
    final snapshot = FinanceSnapshot(expenses: [expense], income: [income]);

    expect(snapshot.monthlyExpenses, 250000);
    expect(snapshot.monthlyIncome, 1000000);
    expect(snapshot.moneyLeft, 750000);
    expect(snapshot.categoryTotals, {'Food': 250000});
  });
}
