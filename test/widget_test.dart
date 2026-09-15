import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_finance_app/features/home/presentation/home_shell.dart';

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
}
