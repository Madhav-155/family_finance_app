import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_finance_app/features/home/presentation/home_shell.dart';
import 'package:family_finance_app/shared/domain/finance_models.dart';

void main() {
  testWidgets('summary card exposes its label and amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            title: 'Income',
            value: 500000,
            color: Colors.blue,
            icon: Icons.wallet,
          ),
        ),
      ),
    );

    expect(find.text('Income'), findsOneWidget);
    expect(find.textContaining('5,000'), findsOneWidget);
  });

  testWidgets('expense edit form is prefilled from history', (tester) async {
    final timestamp = DateTime.utc(2026, 9, 16);
    final expense = Expense(
      id: 'expense',
      householdId: 'family',
      createdBy: 'owner',
      deviceId: 'phone',
      createdAt: timestamp,
      updatedAt: timestamp,
      revision: 1,
      deleted: false,
      amountMinor: 2500,
      category: 'Bills',
      paidBy: 'owner@example.com',
      paymentMode: 'Card',
      date: DateTime(2026, 9, 16),
      notes: 'Electricity',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EntryForm(kind: EntryKind.expense, expense: expense),
          ),
        ),
      ),
    );

    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('25.00'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
  });
}
