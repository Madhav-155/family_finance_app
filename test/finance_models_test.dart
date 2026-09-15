import 'package:family_finance_app/shared/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money values are converted to integer minor units', () {
    expect(rupeesToMinor('1250.50'), 125050);
    expect(rupeesToMinor('invalid'), 0);
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
