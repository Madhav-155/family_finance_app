import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../home/presentation/home_shell.dart';
import '../../../sync/sync_contracts.dart';
import '../application/setup_controller.dart';

class HouseholdSetupGate extends ConsumerWidget {
  const HouseholdSetupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(householdSetupProvider);
    return setup.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => SetupLockedView(
        initialFailure: SyncFailure.from(error, operation: 'load setup'),
      ),
      data: (value) {
        if (value.completed) return const HomeShell();
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const Opacity(opacity: .35, child: HomeShell()),
              ),
            ),
            const ModalBarrier(dismissible: false, color: Color(0x99000000)),
            SetupLockedView(initialFailure: value.error),
          ],
        );
      },
    );
  }
}

class SetupLockedView extends ConsumerStatefulWidget {
  const SetupLockedView({super.key, this.initialFailure});

  final SyncFailure? initialFailure;

  @override
  ConsumerState<SetupLockedView> createState() => _SetupLockedViewState();
}

class _SetupLockedViewState extends ConsumerState<SetupLockedView> {
  final _formKey = GlobalKey<FormState>();
  final _householdName = TextEditingController(text: 'My Family');
  final _memberEmails = TextEditingController();
  final _spreadsheet = TextEditingController();
  HouseholdSetupRole _role = HouseholdSetupRole.owner;

  @override
  void dispose() {
    _householdName.dispose();
    _memberEmails.dispose();
    _spreadsheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSetup = ref.watch(householdSetupProvider);
    final setup = asyncSetup.value ?? const HouseholdSetupState();
    final failure = setup.error ?? widget.initialFailure;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Semantics(
          namesRoute: true,
          scopesRoute: true,
          explicitChildNodes: true,
          label: 'Required family finance setup',
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            child: Icon(LucideIcons.housePlug, size: 28),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Connect your household',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Each family member signs in with their own Google '
                            'account. Finance features unlock only after the '
                            'shared household is verified and synced.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          SegmentedButton<HouseholdSetupRole>(
                            segments: const [
                              ButtonSegment(
                                value: HouseholdSetupRole.owner,
                                icon: Icon(LucideIcons.crown),
                                label: Text('Owner / Create'),
                              ),
                              ButtonSegment(
                                value: HouseholdSetupRole.member,
                                icon: Icon(LucideIcons.users),
                                label: Text('Member / Join'),
                              ),
                            ],
                            selected: {_role},
                            onSelectionChanged: setup.inProgress
                                ? null
                                : (value) =>
                                      setState(() => _role = value.first),
                          ),
                          const SizedBox(height: 16),
                          if (_role == HouseholdSetupRole.owner) ...[
                            TextFormField(
                              controller: _householdName,
                              enabled: !setup.inProgress,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Household name',
                                helperText: 'A new app-managed Google Sheet will be created.',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter a household name.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _memberEmails,
                              enabled: !setup.inProgress,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Member Google emails (optional)',
                                helperText: 'Separate multiple addresses with commas. The Sheet will be shared with each address.',
                              ),
                            ),
                          ] else
                            TextFormField(
                              controller: _spreadsheet,
                              enabled: !setup.inProgress,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Shared Sheet link or ID',
                                helperText: 'Use only the app-created Sheet explicitly shared by the owner.',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Paste the household Sheet link or ID.'
                                  : null,
                            ),
                          if (setup.inProgress) ...[
                            const SizedBox(height: 20),
                            LinearProgressIndicator(
                              semanticsLabel: _stageLabel(setup.stage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _stageLabel(setup.stage),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (failure != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(LucideIcons.triangleAlert),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(failure.userMessage),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: setup.inProgress ? null : _submit,
                            icon: const Icon(LucideIcons.logIn),
                            label: Text(
                              _role == HouseholdSetupRole.owner
                                  ? 'Sign in & create household'
                                  : 'Sign in & join household',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.wifiOff, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'First-time setup needs internet. After setup, '
                                  'temporary network outages never block local '
                                  'finance access; changes queue for later sync.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Roles are enforced in the app UI. Anyone with '
                            'direct editor access to the Sheet can modify its data.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(householdSetupProvider.notifier);
    if (_role == HouseholdSetupRole.owner) {
      final emails = _memberEmails.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      await controller.createOwner(
        householdName: _householdName.text.trim(),
        memberEmails: emails,
      );
    } else {
      await controller.joinMember(_spreadsheet.text.trim());
    }
  }

  String _stageLabel(SetupStage stage) => switch (stage) {
    SetupStage.chooseRole => 'Choose how this device joins the family.',
    SetupStage.connectingAccount => 'Connecting your Google account…',
    SetupStage.authorizing => 'Checking Sheets and Drive permissions…',
    SetupStage.configuringHousehold => 'Verifying the household…',
    SetupStage.initialSync => 'Completing the first secure sync…',
    SetupStage.complete => 'Setup complete.',
  };
}
