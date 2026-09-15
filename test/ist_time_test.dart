import 'package:family_finance_app/core/time/ist_time.dart';
import 'package:family_finance_app/shared/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(IstTime.initialize);

  test('UTC instant is converted to the correct IST calendar date', () {
    final instant = DateTime.parse('2026-08-31T18:30:00Z');

    expect(IstTime.dateOnlyFromStoredInstant(instant), DateTime(2026, 9));
  });

  test('monthly totals use IST month boundaries', () {
    final septemberInstant = DateTime.parse('2026-08-31T18:35:00Z');
    final common = DateTime(2026, 9);
    final septemberIncome = IncomeEntry(
      id: 'september',
      householdId: 'family',
      createdBy: 'owner',
      deviceId: 'device',
      createdAt: common,
      updatedAt: common,
      revision: 1,
      deleted: false,
      source: 'September salary',
      amountMinor: 50000,
      receivedDate: DateTime(2026, 9),
    );
    final augustIncome = IncomeEntry(
      id: 'august',
      householdId: 'family',
      createdBy: 'owner',
      deviceId: 'device',
      createdAt: common,
      updatedAt: common,
      revision: 1,
      deleted: false,
      source: 'August salary',
      amountMinor: 70000,
      receivedDate: DateTime(2026, 8, 31),
    );

    final snapshot = FinanceSnapshot(
      income: [septemberIncome, augustIncome],
      nowInstant: septemberInstant,
    );

    expect(snapshot.monthlyIncome, 50000);
  });

  test('IST today boundary does not follow device local time', () {
    final justAfterIstMidnight = DateTime.parse('2026-09-01T18:31:00Z');

    expect(
      IstTime.isToday(DateTime(2026, 9, 2), nowInstant: justAfterIstMidnight),
      isTrue,
    );
  });
}
