import 'package:family_finance_app/features/onboarding/application/setup_controller.dart';
import 'package:family_finance_app/shared/providers/app_providers.dart';
import 'package:family_finance_app/sync/sync_contracts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySetupStorage extends SetupStorage {
  SetupRecord? value;

  @override
  Future<SetupRecord?> read() async => value;

  @override
  Future<void> write(SetupRecord record) async => value = record;

  @override
  Future<void> clear() async => value = null;
}

class _FakeFamilySyncService implements FamilySyncService {
  Object? ownerError;
  Object? memberError;
  Object? validationError;
  bool signedOut = false;

  @override
  String? get signedInEmail => 'owner@example.com';

  @override
  SyncStatus get status => const SyncStatus(signedInEmail: 'owner@example.com');

  @override
  Stream<SyncStatus> get statuses => const Stream.empty();

  @override
  Future<SetupRecord> createOwnerHousehold({
    required String householdName,
    List<String> memberEmails = const [],
  }) async {
    if (ownerError case final error?) throw error;
    return SetupRecord(
      role: HouseholdSetupRole.owner,
      email: 'owner@example.com',
      spreadsheetId: 'owner-sheet-id-12345678901234567890',
      householdId: 'family',
      completedAt: DateTime.utc(2026, 9, 16),
    );
  }

  @override
  Future<SetupRecord> joinMemberHousehold(String spreadsheetInput) async {
    if (memberError case final error?) throw error;
    return SetupRecord(
      role: HouseholdSetupRole.member,
      email: 'member@example.com',
      spreadsheetId: spreadsheetInput,
      householdId: 'family',
      completedAt: DateTime.utc(2026, 9, 16),
    );
  }

  @override
  Future<void> validateSetup(SetupRecord setup) async {
    if (validationError case final error?) throw error;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> shareWith(String email) async {}

  @override
  Future<SyncStatus> signIn({String? expectedEmail}) async => status;

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  Future<SyncStatus> syncNow({SetupRecord? setup}) async => status;
}

ProviderContainer _container(
  _FakeFamilySyncService sync,
  _MemorySetupStorage storage,
) => ProviderContainer(
  overrides: [
    syncServiceProvider.overrideWithValue(sync),
    setupStorageProvider.overrideWithValue(storage),
  ],
);

void main() {
  test('owner setup persists verified household and unlocks app', () async {
    final sync = _FakeFamilySyncService();
    final storage = _MemorySetupStorage();
    final container = _container(sync, storage);
    addTearDown(container.dispose);
    await container.read(householdSetupProvider.future);

    await container
        .read(householdSetupProvider.notifier)
        .createOwner(householdName: 'My Family', memberEmails: const []);

    final state = container.read(householdSetupProvider).requireValue;
    expect(state.completed, isTrue);
    expect(state.record?.role, HouseholdSetupRole.owner);
    expect(storage.value?.email, 'owner@example.com');
  });

  test('member setup keeps the member identity and shared sheet', () async {
    final sync = _FakeFamilySyncService();
    final storage = _MemorySetupStorage();
    final container = _container(sync, storage);
    addTearDown(container.dispose);
    await container.read(householdSetupProvider.future);

    await container
        .read(householdSetupProvider.notifier)
        .joinMember('member-sheet-id-12345678901234567890');

    final record = container.read(householdSetupProvider).requireValue.record;
    expect(record?.role, HouseholdSetupRole.member);
    expect(record?.email, 'member@example.com');
  });

  test('canceled sign-in remains locked with actionable state', () async {
    final sync = _FakeFamilySyncService()
      ..ownerError = const SyncFailure(
        kind: SyncFailureKind.canceled,
        userMessage: 'Google sign-in was canceled.',
        diagnostic: 'test',
      );
    final storage = _MemorySetupStorage();
    final container = _container(sync, storage);
    addTearDown(container.dispose);
    await container.read(householdSetupProvider.future);

    await container
        .read(householdSetupProvider.notifier)
        .createOwner(householdName: 'My Family', memberEmails: const []);

    final state = container.read(householdSetupProvider).requireValue;
    expect(state.completed, isFalse);
    expect(state.error?.kind, SyncFailureKind.canceled);
  });

  test('offline revalidation preserves completed local access', () async {
    final record = SetupRecord(
      role: HouseholdSetupRole.owner,
      email: 'owner@example.com',
      spreadsheetId: 'owner-sheet-id-12345678901234567890',
      householdId: 'family',
      completedAt: DateTime.utc(2026, 9, 16),
    );
    final sync = _FakeFamilySyncService()
      ..validationError = const SyncFailure(
        kind: SyncFailureKind.offline,
        userMessage: 'No network connection.',
        diagnostic: 'test',
      );
    final storage = _MemorySetupStorage()..value = record;
    final container = _container(sync, storage);
    addTearDown(container.dispose);
    await container.read(householdSetupProvider.future);
    await container.read(householdSetupProvider.notifier).retryValidation();

    final state = container.read(householdSetupProvider).requireValue;
    expect(state.completed, isTrue);
    expect(state.syncHealth, contains('Offline'));
  });

  test('invalid member sheet remains locked', () async {
    final sync = _FakeFamilySyncService()
      ..memberError = const SyncFailure(
        kind: SyncFailureKind.invalidHousehold,
        userMessage: 'This Sheet is not a valid household.',
        diagnostic: 'test',
      );
    final storage = _MemorySetupStorage();
    final container = _container(sync, storage);
    addTearDown(container.dispose);
    await container.read(householdSetupProvider.future);

    await container
        .read(householdSetupProvider.notifier)
        .joinMember('invalid-sheet-id-12345678901234567890');

    final state = container.read(householdSetupProvider).requireValue;
    expect(state.completed, isFalse);
    expect(state.error?.kind, SyncFailureKind.invalidHousehold);
  });
}
