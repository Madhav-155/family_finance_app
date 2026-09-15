import 'package:family_finance_app/features/onboarding/application/setup_controller.dart';
import 'package:family_finance_app/features/onboarding/presentation/setup_gate.dart';
import 'package:family_finance_app/sync/sync_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSetupController extends HouseholdSetupController {
  @override
  Future<HouseholdSetupState> build() async => const HouseholdSetupState();
}

void main() {
  testWidgets('first launch offers owner and member setup', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdSetupProvider.overrideWith(_FakeSetupController.new),
        ],
        child: const MaterialApp(home: SetupLockedView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner / Create'), findsOneWidget);
    expect(find.text('Member / Join'), findsOneWidget);
    expect(
      find.textContaining('First-time setup needs internet'),
      findsOneWidget,
    );
    expect(find.textContaining('direct editor access'), findsOneWidget);
  });

  testWidgets('setup displays actionable errors without raw exceptions', (
    tester,
  ) async {
    const failure = SyncFailure(
      kind: SyncFailureKind.noGoogleAccount,
      userMessage: 'No Google account is available on this Android device. Add an account in Android Settings, then retry.',
      diagnostic: 'internal detail',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdSetupProvider.overrideWith(_FakeSetupController.new),
        ],
        child: const MaterialApp(
          home: SetupLockedView(initialFailure: failure),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Android Settings'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });
}
