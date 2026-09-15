import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../../sync/sync_contracts.dart';

enum SetupStage {
  chooseRole,
  connectingAccount,
  authorizing,
  configuringHousehold,
  initialSync,
  complete,
}

class HouseholdSetupState {
  const HouseholdSetupState({
    this.record,
    this.stage = SetupStage.chooseRole,
    this.inProgress = false,
    this.error,
    this.syncHealth,
  });

  final SetupRecord? record;
  final SetupStage stage;
  final bool inProgress;
  final SyncFailure? error;
  final String? syncHealth;

  bool get completed => record != null;

  HouseholdSetupState copyWith({
    SetupRecord? record,
    bool clearRecord = false,
    SetupStage? stage,
    bool? inProgress,
    SyncFailure? error,
    bool clearError = false,
    String? syncHealth,
  }) => HouseholdSetupState(
    record: clearRecord ? null : record ?? this.record,
    stage: stage ?? this.stage,
    inProgress: inProgress ?? this.inProgress,
    error: clearError ? null : error ?? this.error,
    syncHealth: syncHealth ?? this.syncHealth,
  );
}

final setupStorageProvider = Provider<SetupStorage>(
  (ref) => const SetupStorage(),
);

final householdSetupProvider =
    AsyncNotifierProvider<HouseholdSetupController, HouseholdSetupState>(
      HouseholdSetupController.new,
    );

class HouseholdSetupController extends AsyncNotifier<HouseholdSetupState> {
  @override
  Future<HouseholdSetupState> build() async {
    final record = await ref.read(setupStorageProvider).read();
    final initial = HouseholdSetupState(
      record: record,
      stage: record == null ? SetupStage.chooseRole : SetupStage.complete,
      syncHealth: record == null ? null : 'Local access available.',
    );
    if (record != null) {
      unawaited(Future<void>(() => _revalidate(record)));
    }
    return initial;
  }

  Future<void> createOwner({
    required String householdName,
    required List<String> memberEmails,
  }) async {
    await _performSetup(() async {
      _setStage(SetupStage.connectingAccount);
      final service = ref.read(syncServiceProvider);
      _setStage(SetupStage.authorizing);
      _setStage(SetupStage.configuringHousehold);
      final record = await service.createOwnerHousehold(
        householdName: householdName,
        memberEmails: memberEmails,
      );
      _setStage(SetupStage.initialSync);
      return record;
    });
  }

  Future<void> joinMember(String spreadsheetLinkOrId) async {
    await _performSetup(() async {
      _setStage(SetupStage.connectingAccount);
      final service = ref.read(syncServiceProvider);
      _setStage(SetupStage.authorizing);
      _setStage(SetupStage.configuringHousehold);
      final record = await service.joinMemberHousehold(spreadsheetLinkOrId);
      _setStage(SetupStage.initialSync);
      return record;
    });
  }

  Future<void> retryValidation() async {
    final current = state.value;
    final record = current?.record;
    if (record == null) return;
    await _revalidate(record, interactive: true);
  }

  Future<void> lockAfterRevocation(SyncFailure failure) async {
    if (!failure.invalidatesCompletedSetup) return;
    await ref.read(setupStorageProvider).clear();
    state = AsyncData(
      HouseholdSetupState(error: failure, syncHealth: failure.userMessage),
    );
  }

  Future<void> reset() async {
    await ref.read(setupStorageProvider).clear();
    await ref.read(syncServiceProvider).signOut();
    state = const AsyncData(HouseholdSetupState());
  }

  Future<void> _performSetup(Future<SetupRecord> Function() action) async {
    state = const AsyncData(
      HouseholdSetupState(
        stage: SetupStage.connectingAccount,
        inProgress: true,
      ),
    );
    try {
      final record = await action();
      await ref.read(setupStorageProvider).write(record);
      state = AsyncData(
        HouseholdSetupState(
          record: record,
          stage: SetupStage.complete,
          syncHealth: 'Google connection verified. Offline access enabled.',
        ),
      );
    } on Object catch (error) {
      final failure = SyncFailure.from(error, operation: 'first-run setup');
      state = AsyncData(
        HouseholdSetupState(stage: SetupStage.chooseRole, error: failure),
      );
    }
  }

  Future<void> _revalidate(
    SetupRecord record, {
    bool interactive = false,
  }) async {
    try {
      await ref.read(syncServiceProvider).validateSetup(record);
      final validated = record.copyWith(
        lastValidatedAt: DateTime.now().toUtc(),
      );
      await ref.read(setupStorageProvider).write(validated);
      state = AsyncData(
        HouseholdSetupState(
          record: validated,
          stage: SetupStage.complete,
          syncHealth: 'Google access verified.',
        ),
      );
    } on Object catch (error) {
      final failure = SyncFailure.from(error, operation: 'setup validation');
      if (failure.kind == SyncFailureKind.offline) {
        state = AsyncData(
          HouseholdSetupState(
            record: record,
            stage: SetupStage.complete,
            syncHealth: 'Offline. Local finance features remain available; sync will retry later.',
          ),
        );
      } else if (failure.invalidatesCompletedSetup) {
        await ref.read(setupStorageProvider).clear();
        state = AsyncData(
          HouseholdSetupState(error: failure, syncHealth: failure.userMessage),
        );
      } else {
        state = AsyncData(
          HouseholdSetupState(
            record: record,
            stage: SetupStage.complete,
            error: interactive ? failure : null,
            syncHealth: failure.userMessage,
          ),
        );
      }
    }
  }

  void _setStage(SetupStage stage) {
    final current = state.value ?? const HouseholdSetupState();
    state = AsyncData(
      current.copyWith(stage: stage, inProgress: true, clearError: true),
    );
  }
}
